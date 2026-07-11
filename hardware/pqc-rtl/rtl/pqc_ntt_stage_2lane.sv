// pqc_ntt_stage_2lane.sv
//
// M2 Vaihe 2c: YLEINEN 2-lanen NTT-taso-moduuli. Kayttaa samaa lane_fsm:aa
// kuin kaikki aiemmat vaiheet, mutta pair_dist, base_addr ja zeta ovat
// AJONAIKAISIA portteja (ei compile-time-parametreja) - sama instanssi
// voidaan ajaa uudelleen eri arvoilla peräkkäisille NTT-tasoille ilman
// uudelleensynteesia.
//
// EI muuta pqc_rvv_cluster_2lane.sv:a eika pqc_ntt_level6_2lane.sv:a -
// molemmat pysyvat muuttumattomina, oma erillinen moduulinsa.
//
// KAYTTAYTYMISMALLI (behavioral), EI synteesikelpoinen RTL.
//
// SKOOPIN RAJAUS: kumpikin lane kasittelee TASAN YHDEN NTT-ryhman
// (start-arvon) kokonaan, omalla zeta-arvollaan. Tama riittaa tasoille
// 6 (1 ryhma, molemmat lanet jakavat sen) ja 5 (2 ryhmaa, yksi lane per
// ryhma) - tasoilla joissa on enemman kuin 2 ryhmaa (4..0) tarvitaan
// useampi peräkkäinen kutsu tälle samalle moduulille eri base_addr/
// zeta-arvoilla, tai laajennus useampaan laneen (ei tässä vaiheessa).

`timescale 1ns/1ps

module pqc_ntt_stage_2lane #(
    parameter int COEFF_W = 16,
    parameter int SPAD_AW = 9
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [7:0] count,
    input  logic [7:0] pair_dist,
    input  logic [SPAD_AW-1:0] base_addr_lane0,
    input  logic [SPAD_AW-1:0] base_addr_lane1,
    input  logic [COEFF_W-1:0] zeta_lane0,
    input  logic [COEFF_W-1:0] zeta_lane1,

    output logic stage_done
);

  logic [COEFF_W-1:0] mem [0:511];  // 512 sanaa riittaa kaikille 256-pisteen tarpeille

  logic [SPAD_AW-1:0] addr_a0, addr_b0, addr_a1, addr_b1;
  logic [COEFF_W-1:0] rdata_a0, rdata_b0, rdata_a1, rdata_b1;
  logic [COEFF_W-1:0] wdata_a0, wdata_b0, wdata_a1, wdata_b1;
  logic req0, req1, is_write0, is_write1;
  logic [2:0] state0_w, state1_w;
  logic done0, done1;
  logic [7:0] idx0, idx1;

  // Ei pankkikonfliktia - lane0/lane1 kirjoittavat eri osoitealueita
  // kunhan base_addr_lane0/1 valitaan niin etta ne eivat menne paallekkain.
  logic grant0, grant1;
  assign grant0 = req0;
  assign grant1 = req1;

  lane_fsm #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW)) lane0 (
    .clk(clk), .reset(reset), .start(start),
    .base_addr(base_addr_lane0), .stride(8'd1), .count(count), .pair_dist(pair_dist),
    .mem_addr_a(addr_a0), .mem_addr_b(addr_b0),
    .mem_rdata_a(rdata_a0), .mem_rdata_b(rdata_b0),
    .mem_wdata_a(wdata_a0), .mem_wdata_b(wdata_b0),
    .zeta_in(zeta_lane0),
    .req(req0), .is_write(is_write0), .grant(grant0),
    .state(state0_w), .done(done0), .idx_out(idx0)
  );

  lane_fsm #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW)) lane1 (
    .clk(clk), .reset(reset), .start(start),
    .base_addr(base_addr_lane1), .stride(8'd1), .count(count), .pair_dist(pair_dist),
    .mem_addr_a(addr_a1), .mem_addr_b(addr_b1),
    .mem_rdata_a(rdata_a1), .mem_rdata_b(rdata_b1),
    .mem_wdata_a(wdata_a1), .mem_wdata_b(wdata_b1),
    .zeta_in(zeta_lane1),
    .req(req1), .is_write(is_write1), .grant(grant1),
    .state(state1_w), .done(done1), .idx_out(idx1)
  );

  assign rdata_a0 = mem[addr_a0];
  assign rdata_b0 = mem[addr_b0];
  assign rdata_a1 = mem[addr_a1];
  assign rdata_b1 = mem[addr_b1];

  always_ff @(posedge clk) begin
    if (grant0 && is_write0) begin
      mem[addr_a0] <= wdata_a0;
      mem[addr_b0] <= wdata_b0;
    end
    if (grant1 && is_write1) begin
      mem[addr_a1] <= wdata_a1;
      mem[addr_b1] <= wdata_b1;
    end
  end

  assign stage_done = done0 && done1;

endmodule
