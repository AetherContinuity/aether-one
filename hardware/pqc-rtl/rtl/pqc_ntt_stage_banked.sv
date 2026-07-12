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

`timescale 1ns/1ps

module pqc_ntt_stage_banked #(
    parameter int COEFF_W = 16,
    parameter int SPAD_AW = 9
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
    output logic bank_conflict_detected
);

  // --- ROMit: looginen osoite (0..255) -> (pankki, paikallinen_osoite) ---
  // Samat ROMit kuin 3b:ssa - sama muodollisesti todistettu kuvaus.
  logic [1:0] bank_rom  [0:255];
  logic [5:0] local_rom [0:255];
  initial begin
    $readmemh("m2-golden/bank_rom_4banks.memh", bank_rom);
    $readmemh("m2-golden/bank_local_4banks.memh", local_rom);
  end

  logic [COEFF_W-1:0] bank0 [0:63];
  logic [COEFF_W-1:0] bank1 [0:63];
  logic [COEFF_W-1:0] bank2 [0:63];
  logic [COEFF_W-1:0] bank3 [0:63];

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

  lane_fsm #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW)) lane0 (
    .clk(clk), .reset(reset), .start(start),
    .base_addr(base_addr_lane0), .stride(8'd1), .count(count), .pair_dist(pair_dist), .mode(mode),
    .mem_addr_a(addr_a0), .mem_addr_b(addr_b0),
    .mem_rdata_a(rdata_a0), .mem_rdata_b(rdata_b0),
    .mem_wdata_a(wdata_a0), .mem_wdata_b(wdata_b0),
    .zeta_in(zeta_lane0),
    .req(req0), .is_write(is_write0), .grant(grant0),
    .state(state0_w), .done(done0), .idx_out(idx0)
  );

  lane_fsm #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW)) lane1 (
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

  assign stage_done = done0 && done1;

endmodule
