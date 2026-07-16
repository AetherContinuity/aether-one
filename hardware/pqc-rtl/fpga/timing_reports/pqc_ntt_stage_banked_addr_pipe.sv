// pqc_ntt_stage_banked.sv
//
// M2 Vaihe 3c: YLEINEN, 4-pankkinen NTT-taso-moduuli. Yhdistaa M2 Vaihe
// 2c-ii:n ajonaikaisen parametroinnin (pair_dist, base_addr, zeta per
// lane - sama rajapinta kuin pqc_ntt_stage_2lane.sv) M2 Vaihe 3a/3b:n
// muodollisesti todistettuun 4-pankkiseen muistikuvaukseen.
//
// EI muuta pqc_ntt_stage_2lane.sv:a, pqc_ntt_level6_banked.sv:a eika
// lane_fsm:aa - kaikki pysyvat muuttumattomina, oma erillinen moduulinsa.
//
// KAYTTAYTYMISMALLI (behavioral), EI synteesikelpoinen RTL.
//
// Todistaa: sama laskenta kuin 2c-ii (kaikki 7 tasoa, tasoriippumaton
// yleinen moduuli) MUTTA oikealla 4-pankkisella muistilla jokaisella
// tasolla, ei yhdella isolla taulukolla. Ajonaikainen konfliktin-
// tunnistus jokaisella syklilla jokaisella tasolla.
//
// M4-FPGA-001 (2026-07-14): lisatty VALINNAINEN FPGA_BRINGUP-parametri
// (oletus 0 - EI vaikuta olemassa olevaan kayttoon/testeihin lainkaan).
// Tausta: Yosysin/SystemVerilog-tuen nykyiset rajoitukset estavat
// hierarkkisten viittausten JA bind-rakenteen kayton pankkien sisallon
// paljastamiseen ulkopuolelle synteesissa (molemmat kokeiltu ja
// todettu toimimattomiksi, ks. M4_FPGA_BRINGUP_NOTE.md) - siksi
// lisatty EKSPLISIITTINEN, valinnainen porttirajapinta. TARKEA RAJAUS:
// nama portit paljastavat VAIN olemassa olevan tilan (muistien
// alkuarvojen kirjoitus + lopputulosten luku) - EIVAT muuta
// butterfly-laskentaa, FSM:aa, osoitelaskentaa tai mitaan NTT-
// operaatiota. Kun FPGA_BRINGUP=0 (oletus), bring-up-logiikka
// synteesoituu kokonaan pois - taysin identtinen aiempaan nahden.

`timescale 1ns/1ps

module pqc_ntt_stage_banked_addr_pipe #(
    parameter int COEFF_W = 16,
    parameter int SPAD_AW = 9,
    parameter bit FPGA_BRINGUP = 1'b0,  // oletus 0: ei vaikutusta olemassa olevaan kayttoon
    parameter int NTT_READ_LATENCY = 0  // M4-FPGA-002C (2026-07-17): 0 =
        // TASMALLEEN nykyinen kaytos (kombinatorinen pankkiluku,
        // lane_fsm:n oma READ_LATENCY=0) - EI vaikuta olemassa olevaan
        // kayttoon lainkaan. 1 = rekisteroity pankkiluku (BRAM-
        // yhteensopiva) + lane_fsm:n oma READ_LATENCY=1 (S_WAIT_READ,
        // ks. M4_FPGA_BRAM_STUDY.md). VAIN muistin lukupolku ja
        // lane_fsm:n ajoitusprotokolla muuttuvat - butterfly,
        // osoitegeneraattori, bank_rom/local_rom-kartoitus ja
        // kierrosjarjestys pysyvat TAYSIN koskemattomina.
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [7:0] count,
    input  logic [7:0] pair_dist,
    input  logic mode,  // M3 Issue #8 Vaihe 3: 0=FORWARD, 1=INVERSE (ks. NTT_INVERSE_DESIGN_NOTE.md)
    input  logic [SPAD_AW-1:0] base_addr_lane0,
    input  logic [SPAD_AW-1:0] base_addr_lane1,
    input  logic [COEFF_W-1:0] zeta_lane0,
    input  logic [COEFF_W-1:0] zeta_lane1,

    output logic stage_done,
    output logic bank_conflict_detected,

    // --- M4-FPGA-001 bring-up-portit (kaytossa VAIN jos FPGA_BRINGUP=1) ---
    input  logic load_valid,
    input  logic [7:0] load_addr,           // looginen kerroinindeksi 0..255
    input  logic [COEFF_W-1:0] load_data,
    input  logic read_en,
    input  logic [7:0] read_addr,           // looginen kerroinindeksi 0..255
    output logic read_valid,
    output logic [COEFF_W-1:0] read_data
);

  // --- ROMit: looginen osoite (0..255) -> (pankki, paikallinen_osoite) ---
  // Samat ROMit kuin 3b:ssa - sama muodollisesti todistettu kuvaus.
  logic [1:0] bank_rom  [0:255];
  logic [5:0] local_rom [0:255];
  initial begin
    $readmemh("m2-golden/bank_rom_4banks.memh", bank_rom);
    $readmemh("m2-golden/bank_local_4banks.memh", local_rom);
  end

  // M4-FPGA-004 Vaihe 4 (2026-07-19): pankkien koko kasvatettu 128:aan
  // KUN NTT_READ_LATENCY=1 (BRAM-yhteensopivuutta varten, todistettu
  // valttamattomaksi M4-FPGA-002E:ssa - ainoastaan local-indeksit
  // 0-63 ovat koskaan kaytossa, loput ovat pelkkaa ylimitoitusta).
  // NTT_READ_LATENCY=0:lla pankit pysyvat TASMALLEEN 64-kokoisina -
  // ei muutosta resurssienkayttoon nykyisessa kaytossa.
  localparam int BANK_DEPTH = (NTT_READ_LATENCY == 0) ? 64 : 128;
  logic [COEFF_W-1:0] bank0 [0:BANK_DEPTH-1];
  logic [COEFF_W-1:0] bank1 [0:BANK_DEPTH-1];
  logic [COEFF_W-1:0] bank2 [0:BANK_DEPTH-1];
  logic [COEFF_W-1:0] bank3 [0:BANK_DEPTH-1];

  logic [SPAD_AW-1:0] addr_a0, addr_b0, addr_a1, addr_b1;
  logic [COEFF_W-1:0] rdata_a0, rdata_b0, rdata_a1, rdata_b1;
  logic [COEFF_W-1:0] wdata_a0, wdata_b0, wdata_a1, wdata_b1;
  logic req0, req1, is_write0, is_write1;
  logic [2:0] state0_w, state1_w;
  logic done0, done1;
  logic [7:0] idx0, idx1;

  logic grant0, grant1;
  assign grant0 = req0;
  assign grant1 = req1;

  lane_fsm_addr_pipe #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW), .READ_LATENCY(NTT_READ_LATENCY)) lane0 (
    .clk(clk), .reset(reset), .start(start),
    .base_addr(base_addr_lane0), .stride(8'd1), .count(count), .pair_dist(pair_dist), .mode(mode),
    .mem_addr_a(addr_a0), .mem_addr_b(addr_b0),
    .mem_rdata_a(rdata_a0), .mem_rdata_b(rdata_b0),
    .mem_wdata_a(wdata_a0), .mem_wdata_b(wdata_b0),
    .zeta_in(zeta_lane0),
    .req(req0), .is_write(is_write0), .grant(grant0),
    .state(state0_w), .done(done0), .idx_out(idx0)
  );

  lane_fsm_addr_pipe #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW), .READ_LATENCY(NTT_READ_LATENCY)) lane1 (
    .clk(clk), .reset(reset), .start(start),
    .base_addr(base_addr_lane1), .stride(8'd1), .count(count), .pair_dist(pair_dist), .mode(mode),
    .mem_addr_a(addr_a1), .mem_addr_b(addr_b1),
    .mem_rdata_a(rdata_a1), .mem_rdata_b(rdata_b1),
    .mem_wdata_a(wdata_a1), .mem_wdata_b(wdata_b1),
    .zeta_in(zeta_lane1),
    .req(req1), .is_write(is_write1), .grant(grant1),
    .state(state1_w), .done(done1), .idx_out(idx1)
  );

  wire [1:0] pb_a0 = bank_rom[addr_a0];  wire [5:0] pl_a0 = local_rom[addr_a0];
  wire [1:0] pb_b0 = bank_rom[addr_b0];  wire [5:0] pl_b0 = local_rom[addr_b0];
  wire [1:0] pb_a1 = bank_rom[addr_a1];  wire [5:0] pl_a1 = local_rom[addr_a1];
  wire [1:0] pb_b1 = bank_rom[addr_b1];  wire [5:0] pl_b1 = local_rom[addr_b1];

  logic conflict_flag;
  always_comb begin
    conflict_flag = 1'b0;
    if (grant0 && grant1) begin
      if (pb_a0 == pb_a1 || pb_a0 == pb_b1 || pb_b0 == pb_a1 || pb_b0 == pb_b1) begin
        conflict_flag = 1'b1;
      end
    end
  end
  assign bank_conflict_detected = conflict_flag;

  logic [COEFF_W-1:0] fsm_b0, fsm_b1, fsm_b2, fsm_b3;

  // M4-FPGA-002C: lukupolku ehdollinen NTT_READ_LATENCY:n mukaan.
  // NTT_READ_LATENCY=0 (oletus): TASMALLEEN alkuperainen always_comb-
  // lohko, ei muutosta. NTT_READ_LATENCY=1: sama kartoitus (bank_rom/
  // local_rom, pb_a0/pl_a0 jne. - EI KOSKETTU), mutta REKISTEROITY
  // luku (always_ff) - BRAM-yhteensopiva, yhdessa lane_fsm:n oman
  // READ_LATENCY=1:n (S_WAIT_READ) kanssa.
  generate
    if (NTT_READ_LATENCY == 0) begin : g_comb_read
      // KORJATTU (ks. M2 Vaihe 3b): always_comb, ei "assign" automaattista
      // funktiota kayttaen - iverilog ei seuraa oikein sisalla luettuja
      // taulukkoalkioita jatkuvassa sijoituksessa.
      always_comb begin
        case (pb_a0)
          2'd0: rdata_a0 = bank0[pl_a0];
          2'd1: rdata_a0 = bank1[pl_a0];
          2'd2: rdata_a0 = bank2[pl_a0];
          default: rdata_a0 = bank3[pl_a0];
        endcase
        case (pb_b0)
          2'd0: rdata_b0 = bank0[pl_b0];
          2'd1: rdata_b0 = bank1[pl_b0];
          2'd2: rdata_b0 = bank2[pl_b0];
          default: rdata_b0 = bank3[pl_b0];
        endcase
        case (pb_a1)
          2'd0: rdata_a1 = bank0[pl_a1];
          2'd1: rdata_a1 = bank1[pl_a1];
          2'd2: rdata_a1 = bank2[pl_a1];
          default: rdata_a1 = bank3[pl_a1];
        endcase
        case (pb_b1)
          2'd0: rdata_b1 = bank0[pl_b1];
          2'd1: rdata_b1 = bank1[pl_b1];
          2'd2: rdata_b1 = bank2[pl_b1];
          default: rdata_b1 = bank3[pl_b1];
        endcase
      end
    end else begin : g_registered_read
      // M4-FPGA-004 Vaihe 3 (2026-07-19): LUKUARBITROINTI - viisi
      // mahdollista lukulahdetta (lane0.a, lane0.b, lane1.a, lane1.b,
      // bring-up) arbitroitu YHDEKSI fyysiseksi lukurekisteriksi per
      // pankki - sama, todistettu rakenne kuin v10-tutkimusproto-
      // tyypissa (ks. M4_FPGA_003_RC.md). Konfliktittomuustodistus
      // (BANK_MAPPING_PROOF.md) takaa etta korkeintaan yksi FSM-
      // lahteista osuu mihin tahansa yksittaiseen pankkiin per sykli.
      //
      // Bring-up:n oma lukuportti (read_en/read_addr) AIKAJAETTU
      // FSM:n oman arbitroidun lukupolun kanssa - EI kaksi erillista
      // fyysista porttia. OLETUS (kayttajan oma, dokumentoitu
      // M4_FPGA_003_RC.md:ssa): bring-up-luku ei koskaan ole
      // aktiivinen SAMALLA syklilla kuin operatiivinen NTT-laskenta.
      logic [5:0] shared_raddr0, shared_raddr1, shared_raddr2, shared_raddr3;
      always_comb begin
        for (int tb = 0; tb < 4; tb++) begin
          logic [5:0] raddr_t;
          raddr_t = '0;
          if (FPGA_BRINGUP && read_en && bank_rom[read_addr] == tb[1:0]) begin
            raddr_t = local_rom[read_addr];
          end else if (!(FPGA_BRINGUP && read_en)) begin
            if (pb_a0 == tb[1:0]) raddr_t = pl_a0;
            else if (pb_b0 == tb[1:0]) raddr_t = pl_b0;
            else if (pb_a1 == tb[1:0]) raddr_t = pl_a1;
            else if (pb_b1 == tb[1:0]) raddr_t = pl_b1;
          end
          case (tb)
            0: shared_raddr0 = raddr_t;
            1: shared_raddr1 = raddr_t;
            2: shared_raddr2 = raddr_t;
            default: shared_raddr3 = raddr_t;
          endcase
        end
      end

      // M4-FPGA-006B koe: REKISTEROI arbitroitu osoite YHDEN SYKLIN
      // ennen kuin sita kaytetaan pankin osoitteena - erottaa
      // arbitroinnin oman LUT-ketjun (todettu M4-FPGA-006A:ssa
      // kriittiseksi poluksi) BRAM:n omasta osoiteportista.
      logic [5:0] shared_raddr0_reg, shared_raddr1_reg, shared_raddr2_reg, shared_raddr3_reg;
      always_ff @(posedge clk) begin
        shared_raddr0_reg <= shared_raddr0;
        shared_raddr1_reg <= shared_raddr1;
        shared_raddr2_reg <= shared_raddr2;
        shared_raddr3_reg <= shared_raddr3;
      end

      always_ff @(posedge clk) begin
        fsm_b0 <= bank0[shared_raddr0_reg];
        fsm_b1 <= bank1[shared_raddr1_reg];
        fsm_b2 <= bank2[shared_raddr2_reg];
        fsm_b3 <= bank3[shared_raddr3_reg];
      end

      // FSM:n neljan kuluttajan (a0,b0,a1,b1) oma data haetaan
      // SIITA pankista jonka se itse kohdisti - konfliktittomuus-
      // todistus takaa etta VAIN YKSI pankeista voi tasmata.
      always_comb begin
        case (pb_a0) 2'd0: rdata_a0=fsm_b0; 2'd1: rdata_a0=fsm_b1; 2'd2: rdata_a0=fsm_b2; default: rdata_a0=fsm_b3; endcase
        case (pb_b0) 2'd0: rdata_b0=fsm_b0; 2'd1: rdata_b0=fsm_b1; 2'd2: rdata_b0=fsm_b2; default: rdata_b0=fsm_b3; endcase
        case (pb_a1) 2'd0: rdata_a1=fsm_b0; 2'd1: rdata_a1=fsm_b1; 2'd2: rdata_a1=fsm_b2; default: rdata_a1=fsm_b3; endcase
        case (pb_b1) 2'd0: rdata_b1=fsm_b0; 2'd1: rdata_b1=fsm_b1; 2'd2: rdata_b1=fsm_b2; default: rdata_b1=fsm_b3; endcase
      end
    end
  endgenerate

  generate
    if (NTT_READ_LATENCY == 0) begin : g_write_direct
      // TASMALLEEN alkuperainen kaytos - EI muutosta.
      always_ff @(posedge clk) begin
        if (grant0 && is_write0) begin
          case (pb_a0)
            2'd0: bank0[pl_a0] <= wdata_a0;
            2'd1: bank1[pl_a0] <= wdata_a0;
            2'd2: bank2[pl_a0] <= wdata_a0;
            default: bank3[pl_a0] <= wdata_a0;
          endcase
          case (pb_b0)
            2'd0: bank0[pl_b0] <= wdata_b0;
            2'd1: bank1[pl_b0] <= wdata_b0;
            2'd2: bank2[pl_b0] <= wdata_b0;
            default: bank3[pl_b0] <= wdata_b0;
          endcase
        end
        if (grant1 && is_write1) begin
          case (pb_a1)
            2'd0: bank0[pl_a1] <= wdata_a1;
            2'd1: bank1[pl_a1] <= wdata_a1;
            2'd2: bank2[pl_a1] <= wdata_a1;
            default: bank3[pl_a1] <= wdata_a1;
          endcase
          case (pb_b1)
            2'd0: bank0[pl_b1] <= wdata_b1;
            2'd1: bank1[pl_b1] <= wdata_b1;
            2'd2: bank2[pl_b1] <= wdata_b1;
            default: bank3[pl_b1] <= wdata_b1;
          endcase
        end
      end
    end else begin : g_write_arbitrated
      // M4-FPGA-004 Vaihe 2 (2026-07-19): VIISI mahdollista kirjoitus-
      // lahdetta (lane0.a, lane0.b, lane1.a, lane1.b, bring-up)
      // arbitroitu YHDEKSI fyysiseksi kirjoitusportiksi per pankki -
      // sama, todistettu rakenne kuin v10-tutkimusprototyypissa
      // (ks. M4_FPGA_003_RC.md). Konfliktittomuustodistus
      // (BANK_MAPPING_PROOF.md) takaa etta korkeintaan yksi FSM-
      // lahteista osuu mihin tahansa yksittaiseen pankkiin per sykli -
      // arbitrointi on siis matemaattisesti perusteltu, ei
      // optimointikikka. Prioriteettijarjestys: bring-up > lane0.a >
      // lane0.b > lane1.a > lane1.b (vastaa v10:aa).
      logic we0_arb, we1_arb, we2_arb, we3_arb;
      logic [5:0] waddr0_arb, waddr1_arb, waddr2_arb, waddr3_arb;
      logic [COEFF_W-1:0] wdata0_arb, wdata1_arb, wdata2_arb, wdata3_arb;

      always_comb begin
        for (int tb = 0; tb < 4; tb++) begin
          logic we_t; logic [5:0] waddr_t; logic [COEFF_W-1:0] wdata_t;
          we_t = 1'b0; waddr_t = '0; wdata_t = '0;
          if (FPGA_BRINGUP && load_valid && bank_rom[load_addr] == tb[1:0]) begin
            we_t = 1'b1; waddr_t = local_rom[load_addr]; wdata_t = load_data;
          end else if (grant0 && is_write0 && pb_a0 == tb[1:0]) begin
            we_t = 1'b1; waddr_t = pl_a0; wdata_t = wdata_a0;
          end else if (grant0 && is_write0 && pb_b0 == tb[1:0]) begin
            we_t = 1'b1; waddr_t = pl_b0; wdata_t = wdata_b0;
          end else if (grant1 && is_write1 && pb_a1 == tb[1:0]) begin
            we_t = 1'b1; waddr_t = pl_a1; wdata_t = wdata_a1;
          end else if (grant1 && is_write1 && pb_b1 == tb[1:0]) begin
            we_t = 1'b1; waddr_t = pl_b1; wdata_t = wdata_b1;
          end
          case (tb)
            0: begin we0_arb = we_t; waddr0_arb = waddr_t; wdata0_arb = wdata_t; end
            1: begin we1_arb = we_t; waddr1_arb = waddr_t; wdata1_arb = wdata_t; end
            2: begin we2_arb = we_t; waddr2_arb = waddr_t; wdata2_arb = wdata_t; end
            default: begin we3_arb = we_t; waddr3_arb = waddr_t; wdata3_arb = wdata_t; end
          endcase
        end
      end

      always_ff @(posedge clk) begin
        if (we0_arb) bank0[waddr0_arb] <= wdata0_arb;
        if (we1_arb) bank1[waddr1_arb] <= wdata1_arb;
        if (we2_arb) bank2[waddr2_arb] <= wdata2_arb;
        if (we3_arb) bank3[waddr3_arb] <= wdata3_arb;
      end
    end
  endgenerate

  assign stage_done = done0 && done1;

  // --- M4-FPGA-001 bring-up-logiikka (VAIN jos FPGA_BRINGUP=1) ---
  // EI kosketa mitaan yllaolevaa: butterfly-laskenta, FSM, osoite-
  // laskenta ja NTT-operaatiot pysyvat TASMALLEEN samoina. Tama
  // lohko VAIN paljastaa pankkien olemassa olevan sisallon load/read-
  // porttien kautta, uudelleenkayttaen jo olemassa olevaa bank_rom/
  // local_rom-kartoitusta (sama muodollisesti todistettu kuvaus,
  // ei uutta logiikkaa). Kun FPGA_BRINGUP=0 (oletus), tama koko
  // lohko synteesoituu pois - taysin identtinen aiempaan nahden.
  generate
    if (FPGA_BRINGUP) begin : g_bringup
      // M4-FPGA-004: kirjoitus tapahtuu TASSA VAIN kun NTT_READ_LATENCY=0
      // - kun =1, arbitroitu kirjoituslohko (ylla) kasittelee bring-up:n
      // oman load_valid-polun jo osana viiden lahteen arbitrointia,
      // jotta EI synny kaksinkertaista kirjoitusta samaan pankkiin.
      if (NTT_READ_LATENCY == 0) begin : g_bringup_write_direct
      // Kirjoitus: synkroninen, yksi kirjoitusportti (kuten aiemmin)
      always_ff @(posedge clk) begin
        if (load_valid) begin
          case (bank_rom[load_addr])
            2'd0: bank0[local_rom[load_addr]] <= load_data;
            2'd1: bank1[local_rom[load_addr]] <= load_data;
            2'd2: bank2[local_rom[load_addr]] <= load_data;
            default: bank3[local_rom[load_addr]] <= load_data;
          endcase
        end
      end
      end

      // Luku: NTT_READ_LATENCY=0:lla oma erillinen rekisteroity
      // lukupolku (kuten aiemmin). NTT_READ_LATENCY=1:lla read_data
      // haetaan JAETUSTA arbitroidusta lukurekisterista (ylla,
      // g_registered_read) - EI erillista fyysista lukuporttia.
      if (NTT_READ_LATENCY == 0) begin : g_bringup_read_direct
        always_ff @(posedge clk) begin
          if (reset) begin
            read_valid <= 1'b0;
          end else begin
            read_valid <= read_en;
            if (read_en) begin
              case (bank_rom[read_addr])
                2'd0: read_data <= bank0[local_rom[read_addr]];
                2'd1: read_data <= bank1[local_rom[read_addr]];
                2'd2: read_data <= bank2[local_rom[read_addr]];
                default: read_data <= bank3[local_rom[read_addr]];
              endcase
            end
          end
        end
      end else begin : g_bringup_read_shared
        // M4-FPGA-006B koe: fsm_b0-3 paivittyy nyt KAHDEN syklin
        // viiveella (shared_raddr_reg-lisayksen vuoksi) - bring-up:n
        // oma read_valid/osoiteseuranta pitaa synkronoida vastaavasti.
        logic [1:0] read_bank_sel_reg, read_bank_sel_reg2;
        logic read_valid_stage1;
        always_ff @(posedge clk) begin
          if (reset) begin
            read_valid_stage1 <= 1'b0;
            read_valid <= 1'b0;
          end else begin
            read_valid_stage1 <= read_en;
            read_valid <= read_valid_stage1;
          end
          read_bank_sel_reg  <= bank_rom[read_addr];
          read_bank_sel_reg2 <= read_bank_sel_reg;
        end
        always_comb begin
          case (read_bank_sel_reg2)
            2'd0: read_data = fsm_b0;
            2'd1: read_data = fsm_b1;
            2'd2: read_data = fsm_b2;
            default: read_data = fsm_b3;
          endcase
        end
      end
    end else begin : g_no_bringup
      assign read_data = '0;
      assign read_valid = 1'b0;
    end
  endgenerate

endmodule
