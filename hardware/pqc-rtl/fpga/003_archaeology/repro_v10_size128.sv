// v4: KAKSI aitoa lane_fsm-instanssia (lane0, lane1) - vastaa
// oikean ytimen dual-lane-rakennetta.
module repro_v10 (
    input  logic clk, reset, start,
    input  logic [8:0] base_addr0, base_addr1,
    input  logic [7:0] stride, count, pair_dist,
    input  logic mode,
    input  logic [15:0] zeta0, zeta1,
    output logic done0, done1,
  output logic bank_conflict_detected,
  input  logic load_valid,
  input  logic [7:0] load_addr,
  input  logic [15:0] load_data,
  input  logic read_en,
  input  logic [7:0] read_addr,
  output logic read_valid,
  output logic [15:0] read_data
);
  logic [15:0] bank0 [0:127];
  logic [15:0] bank1 [0:127];
  logic [15:0] bank2 [0:127];
  logic [15:0] bank3 [0:127];

  function automatic logic [1:0] bank_of(input logic [8:0] a);
    bank_of = a[1:0] ^ a[3:2] ^ a[5:4] ^ a[7:6] ^ a[8];
  endfunction
  function automatic logic [5:0] local_of(input logic [8:0] a);
    local_of = a[7:2];
  endfunction

  logic [8:0] addr_a0, addr_b0, addr_a1, addr_b1;
  logic [15:0] rdata_a0, rdata_b0, rdata_a1, rdata_b1;
  logic [15:0] wdata_a0, wdata_b0, wdata_a1, wdata_b1;
  logic req0, is_write0, grant0, req1, is_write1, grant1;
  logic [2:0] state0, state1;
  logic [7:0] idx0, idx1;

  assign grant0 = req0;
  assign grant1 = req1;

  lane_fsm #(.COEFF_W(16), .SPAD_AW(9), .READ_LATENCY(1)) lane0 (
    .clk(clk), .reset(reset), .start(start),
    .base_addr(base_addr0), .stride(stride), .count(count), .pair_dist(pair_dist), .mode(mode),
    .mem_addr_a(addr_a0), .mem_addr_b(addr_b0),
    .mem_rdata_a(rdata_a0), .mem_rdata_b(rdata_b0),
    .mem_wdata_a(wdata_a0), .mem_wdata_b(wdata_b0),
    .zeta_in(zeta0), .req(req0), .is_write(is_write0), .grant(grant0),
    .state(state0), .done(done0), .idx_out(idx0)
  );
  lane_fsm #(.COEFF_W(16), .SPAD_AW(9), .READ_LATENCY(1)) lane1 (
    .clk(clk), .reset(reset), .start(start),
    .base_addr(base_addr1), .stride(stride), .count(count), .pair_dist(pair_dist), .mode(mode),
    .mem_addr_a(addr_a1), .mem_addr_b(addr_b1),
    .mem_rdata_a(rdata_a1), .mem_rdata_b(rdata_b1),
    .mem_wdata_a(wdata_a1), .mem_wdata_b(wdata_b1),
    .zeta_in(zeta1), .req(req1), .is_write(is_write1), .grant(grant1),
    .state(state1), .done(done1), .idx_out(idx1)
  );

  wire [1:0] pb_a0 = bank_of(addr_a0); wire [5:0] pl_a0 = local_of(addr_a0);
  wire [1:0] pb_b0 = bank_of(addr_b0); wire [5:0] pl_b0 = local_of(addr_b0);
  wire [1:0] pb_a1 = bank_of(addr_a1); wire [5:0] pl_a1 = local_of(addr_a1);
  wire [1:0] pb_b1 = bank_of(addr_b1); wire [5:0] pl_b1 = local_of(addr_b1);

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

  // M4-FPGA-003A: bring-up-rajapinta SAMA, MUTTA lukutoteutus
  // muutettu mux-vasta-rekisteroinnin-jalkeen-rakenteeksi (sama
  // kuin FSM:n omissa lukuporteissa, v4/v5:ssa jo todistettu
  // toimivaksi) - jokainen pankki saa oman dedikoidun rekisterinsa,
  // valinta VASTA rekisteroinnin jalkeen.
  logic [15:0] br_b0, br_b1, br_b2, br_b3;
// M4-FPGA-003A koe (kayttajan oma ehdotus): YKSI ARBITROITU
  // kirjoituslahde per pankki ENNEN muistia (prioriteettijarjestys:
  // load_valid > a0 > b0 > a1 > b1) - looginen rinnakkaisuus
  // ratkaistaan TASSA, ei muistisolun omassa rajapinnassa.
  logic we0_arb, we1_arb, we2_arb, we3_arb;
  logic [5:0] waddr0_arb, waddr1_arb, waddr2_arb, waddr3_arb;
  logic [15:0] wdata0_arb, wdata1_arb, wdata2_arb, wdata3_arb;

  // Kunkin viiden lahteen oma (bank,local,data,valid) laskettuna:
  wire src_load_valid = load_valid;
  wire [1:0] src_load_bank = bank_of({1'b0,load_addr});
  wire [5:0] src_load_local = local_of({1'b0,load_addr});

  wire src_a0_valid = grant0 && is_write0;
  wire src_b0_valid = grant0 && is_write0;
  wire src_a1_valid = grant1 && is_write1;
  wire src_b1_valid = grant1 && is_write1;

  // (Icarus-yhteensopiva: sama logiikka ilman output-porttifunktiota)
  always_comb begin
    for (int tb = 0; tb < 4; tb++) begin
      logic we_t; logic [5:0] waddr_t; logic [15:0] wdata_t;
      we_t = 1'b0; waddr_t = '0; wdata_t = '0;
      if (src_load_valid && src_load_bank == tb[1:0]) begin
        we_t = 1'b1; waddr_t = src_load_local; wdata_t = load_data;
      end else if (src_a0_valid && pb_a0 == tb[1:0]) begin
        we_t = 1'b1; waddr_t = pl_a0; wdata_t = wdata_a0;
      end else if (src_b0_valid && pb_b0 == tb[1:0]) begin
        we_t = 1'b1; waddr_t = pl_b0; wdata_t = wdata_b0;
      end else if (src_a1_valid && pb_a1 == tb[1:0]) begin
        we_t = 1'b1; waddr_t = pl_a1; wdata_t = wdata_a1;
      end else if (src_b1_valid && pb_b1 == tb[1:0]) begin
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

    if (reset) read_valid <= 1'b0;
    else read_valid <= read_en;
  end

  // M4-FPGA-003A koe (kayttajan oma viimeinen ehdotus): bring-up:n
  // lukuportti AIKAJAETTU FSM:n oman arbitroidun lukuportin kanssa -
  // EI kaksi erillista fyysista porttia, vaan YKSI portti jonka
  // osoite valitaan sen mukaan onko bring-up aktiivinen (read_en)
  // TAMAN syklin. OLETUS (kayttajan oma, dokumentoitu): bring-up-luku
  // ei koskaan ole aktiivinen SAMALLA syklilla kuin operatiivinen
  // NTT-laskenta - paljon heikompi vaatimus kuin ajoitusmuutos koko
  // datapolkuun.

  logic [5:0] shared_raddr0, shared_raddr1, shared_raddr2, shared_raddr3;
  always_comb begin
    for (int tb = 0; tb < 4; tb++) begin
      logic [5:0] raddr_t;
      raddr_t = '0;
      if (read_en && bank_of({1'b0,read_addr}) == tb[1:0]) begin
        raddr_t = local_of({1'b0,read_addr});
      end else if (!read_en) begin
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

  logic [15:0] fsm_b0, fsm_b1, fsm_b2, fsm_b3;
  always_ff @(posedge clk) begin
    fsm_b0 <= bank0[shared_raddr0];
    fsm_b1 <= bank1[shared_raddr1];
    fsm_b2 <= bank2[shared_raddr2];
    fsm_b3 <= bank3[shared_raddr3];
  end

  // read_data (bring-up) haetaan samasta jaetusta rekisterijoukosta -
  // yksi sykli viiveella read_en:sta (sama kuin ennen), mutta EI
  // erillista fyysista lukuporttia enaa.
  logic [1:0] read_bank_sel_reg;
  always_ff @(posedge clk) begin
    read_bank_sel_reg <= bank_of({1'b0,read_addr});
  end
  always_comb begin
    case (read_bank_sel_reg)
      2'd0: read_data = fsm_b0;
      2'd1: read_data = fsm_b1;
      2'd2: read_data = fsm_b2;
      default: read_data = fsm_b3;
    endcase
  end

  // Ristikytkenta: kunkin FSM-kuluttajan (a0,b0,a1,b1) oma data
  // haetaan SIITA pankista jonka se itse kohdisti - VAIN YKSI
  // pankeista voi tasmata (konfliktittomuustodistus), joten
  // taman voi toteuttaa yksinkertaisella case-valinnalla ilman
  // uutta muistiporttia.
  always_comb begin
    case (pb_a0) 2'd0: rdata_a0=fsm_b0; 2'd1: rdata_a0=fsm_b1; 2'd2: rdata_a0=fsm_b2; default: rdata_a0=fsm_b3; endcase
    case (pb_b0) 2'd0: rdata_b0=fsm_b0; 2'd1: rdata_b0=fsm_b1; 2'd2: rdata_b0=fsm_b2; default: rdata_b0=fsm_b3; endcase
    case (pb_a1) 2'd0: rdata_a1=fsm_b0; 2'd1: rdata_a1=fsm_b1; 2'd2: rdata_a1=fsm_b2; default: rdata_a1=fsm_b3; endcase
    case (pb_b1) 2'd0: rdata_b1=fsm_b0; 2'd1: rdata_b1=fsm_b1; 2'd2: rdata_b1=fsm_b2; default: rdata_b1=fsm_b3; endcase
  end
endmodule
