// pqc_ntt_level6_banked.sv
//
// M2 Vaihe 3b: OIKEA 4-pankkinen muisti tasolle 6, kayttaen M2 Vaihe 3a:n
// muodollisesti todistettua (Z3, SAT) osoitekuvausta
// (m2-golden/bank_rom_4banks.memh + bank_local_4banks.memh).
//
// EI muuta lane_fsm:aa (pqc_rvv_cluster_2lane.sv) - kayttaa sita
// muuttumattomana. Uusi asia: looginen osoite (0..255) EI enaa osoita
// suoraan yhteen isoon taulukkoon (kuten 2b/2c-i/2c-ii tekivat) vaan
// kaannetaan ROM-haulla (pankki, paikallinen_osoite) -pariksi, ja
// TODELLINEN data on NELJASSA ERILLISESSA 64-sanan pankissa.
//
// Todistaa: (1) laskenta pysyy oikeana ROM-reitityksen lapi (sama
// tulos kuin 2b:n golden-malli), (2) AJONAIKAINEN tarkistus etta
// molemmat lanet eivat KOSKAAN osu samaan pankkiin samana syklina -
// tama on eri asia kuin 3a:n OFFLINE (Z3) todistus: tama vahvistaa
// etta TODELLINEN, ajettu RTL-osoitegenerointi tosiasiassa noudattaa
// sita mita 3a:ssa oletettiin.
//
// KAYTTAYTYMISMALLI (behavioral), EI synteesikelpoinen RTL.

`timescale 1ns/1ps

module pqc_ntt_level6_banked #(
    parameter int COEFF_W = 16
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [7:0] count,

    input  logic tw_in_valid,
    input  logic [5:0] tw_in_idx,
    input  logic [COEFF_W-1:0] tw_in_data,

    output logic cluster_done,
    output logic bank_conflict_detected  // AJONAIKAINEN tarkistus - pitaisi pysya 0:ssa aina
);

  // --- ROMit: looginen osoite (0..255) -> (pankki, paikallinen_osoite) ---
  logic [1:0] bank_rom  [0:255];
  logic [5:0] local_rom [0:255];
  initial begin
    $readmemh("m2-golden/bank_rom_4banks.memh", bank_rom);
    $readmemh("m2-golden/bank_local_4banks.memh", local_rom);
  end

  // --- Nelja erillista 64-sanan pankkia ---
  logic [COEFF_W-1:0] bank0 [0:63];
  logic [COEFF_W-1:0] bank1 [0:63];
  logic [COEFF_W-1:0] bank2 [0:63];
  logic [COEFF_W-1:0] bank3 [0:63];

  logic [COEFF_W-1:0] tw_window [0:63];
  always_ff @(posedge clk) begin
    if (tw_in_valid) tw_window[tw_in_idx] <= tw_in_data;
  end

  logic [8:0] addr_a0, addr_b0, addr_a1, addr_b1;
  logic [COEFF_W-1:0] rdata_a0, rdata_b0, rdata_a1, rdata_b1;
  logic [COEFF_W-1:0] wdata_a0, wdata_b0, wdata_a1, wdata_b1;
  logic req0, req1, is_write0, is_write1;
  logic [2:0] state0_w, state1_w;
  logic done0, done1;
  logic [7:0] idx0, idx1;

  logic grant0, grant1;
  assign grant0 = req0;
  assign grant1 = req1;

  lane_fsm #(.COEFF_W(COEFF_W), .SPAD_AW(9)) lane0 (
    .clk(clk), .reset(reset), .start(start),
    .base_addr(9'd0), .stride(8'd1), .count(count), .pair_dist(8'd128),
    .mem_addr_a(addr_a0), .mem_addr_b(addr_b0),
    .mem_rdata_a(rdata_a0), .mem_rdata_b(rdata_b0),
    .mem_wdata_a(wdata_a0), .mem_wdata_b(wdata_b0),
    .zeta_in(tw_window[idx0]),
    .req(req0), .is_write(is_write0), .grant(grant0),
    .state(state0_w), .done(done0), .idx_out(idx0)
  );

  lane_fsm #(.COEFF_W(COEFF_W), .SPAD_AW(9)) lane1 (
    .clk(clk), .reset(reset), .start(start),
    .base_addr(9'd64), .stride(8'd1), .count(count), .pair_dist(8'd128),
    .mem_addr_a(addr_a1), .mem_addr_b(addr_b1),
    .mem_rdata_a(rdata_a1), .mem_rdata_b(rdata_b1),
    .mem_wdata_a(wdata_a1), .mem_wdata_b(wdata_b1),
    .zeta_in(tw_window[idx1]),
    .req(req1), .is_write(is_write1), .grant(grant1),
    .state(state1_w), .done(done1), .idx_out(idx1)
  );

  // --- Pankki/paikallisosoite-haku molemmille osoitteille molemmilla laneilla ---
  wire [1:0] pb_a0 = bank_rom[addr_a0];  wire [5:0] pl_a0 = local_rom[addr_a0];
  wire [1:0] pb_b0 = bank_rom[addr_b0];  wire [5:0] pl_b0 = local_rom[addr_b0];
  wire [1:0] pb_a1 = bank_rom[addr_a1];  wire [5:0] pl_a1 = local_rom[addr_a1];
  wire [1:0] pb_b1 = bank_rom[addr_b1];  wire [5:0] pl_b1 = local_rom[addr_b1];

  // --- AJONAIKAINEN TARKISTUS: molemmat lanet eivat koskaan osu samaan
  // pankkiin samana syklina kun molemmat ovat aktiivisia (grant=1) ---
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

  // --- Lukudata: kunkin lanen a/b haetaan OMASTA pankistaan ---
  // KORJATTU 2026-07-11: alkuperainen "assign rdata_a0 = read_bank(...)"
  // (jatkuva sijoitus automaattista funktiota kayttaen) ei paivittynyt
  // oikein kun VAIN pankkitaulukon sisalto muuttui (esim. kirjoitus
  // toisesta lanesta) - iverilog seurasi vain funktion omien argumenttien
  // (pb_a0, pl_a0) muutoksia, ei niiden SISALLA luettuja taulukkoalkioita.
  // always_comb seuraa oikein kaikkea sisalla luettua.
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

  // --- Kirjoitus: jokainen lane kirjoittaa omaan pankkiinsa ---
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

  assign cluster_done = done0 && done1;

endmodule
