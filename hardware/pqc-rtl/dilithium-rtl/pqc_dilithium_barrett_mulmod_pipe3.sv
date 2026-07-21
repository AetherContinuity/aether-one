// pqc_dilithium_barrett_mulmod_pipe3.sv
//
// SYNTH-002: 3-vaiheinen REKISTEROITY versio pqc_dilithium_barrett_
// mulmod.sv:sta. SAMA algoritmi, SAMA funktionaalinen tulos.
//
// VAIHE 1 (syotto -> rekisteri): product = a*b.
// VAIHE 2 (rekisteri -> rekisteri): product_times_m = product*M_CONST;
//   q_est = ylabitit. "product" KULJETETAAN LAPI (rekisteroidaan
//   uudelleen) koska Vaihe 3 tarvitsee sen vahennykseen.
// VAIHE 3 (rekisteri -> ulostulo): q_est_times_q = q_est*Q;
//   r_wide = product - q_est_times_q; ehdollinen loppuvahennys.
//
// KIINTEA 3 syklin latenssi (start->valid).

`timescale 1ns/1ps

module pqc_dilithium_barrett_mulmod_pipe3 #(
    parameter int Q = 8380417,
    parameter longint M_CONST = 8396807,
    parameter int K_SHIFT = 46,
    parameter int CW = 23
)(
    input  logic clk,
    input  logic reset,

    input  logic [CW-1:0] a_in,
    input  logic [CW-1:0] b_in,
    output logic [CW-1:0] result_out
);

  // --- VAIHE 1: product = a*b ---
  logic [2*CW-1:0] product_s1_comb;
  assign product_s1_comb = a_in * b_in;

  logic [2*CW-1:0] product_reg1;
  always_ff @(posedge clk) begin
    if (reset) product_reg1 <= '0;
    else product_reg1 <= product_s1_comb;
  end

  // --- VAIHE 2: q_est = (product*M_CONST)>>K_SHIFT, product kuljetettu lapi ---
  logic [2*CW+24-1:0] product_times_m_s2_comb;
  logic [23:0] q_est_s2_comb;
  assign product_times_m_s2_comb = product_reg1 * M_CONST;
  assign q_est_s2_comb = product_times_m_s2_comb[2*CW+24-1:K_SHIFT];

  logic [2*CW-1:0] product_reg2;
  logic [23:0] q_est_reg2;
  always_ff @(posedge clk) begin
    if (reset) begin
      product_reg2 <= '0;
      q_est_reg2 <= '0;
    end else begin
      product_reg2 <= product_reg1;  // kuljetetaan lapi muuttumattomana
      q_est_reg2 <= q_est_s2_comb;
    end
  end

  // --- VAIHE 3: q_est_times_q, vahennys, normalisointi ---
  logic [46:0] q_est_times_q_s3_comb;
  logic [46:0] r_wide_s3_comb;
  logic [CW-1:0] r_final_s3_comb;

  assign q_est_times_q_s3_comb = q_est_reg2 * Q;
  assign r_wide_s3_comb = {1'b0, product_reg2} - q_est_times_q_s3_comb;
  assign r_final_s3_comb = (r_wide_s3_comb >= Q) ? (r_wide_s3_comb - Q) : r_wide_s3_comb[CW-1:0];

  logic [CW-1:0] result_reg3;
  always_ff @(posedge clk) begin
    if (reset) result_reg3 <= '0;
    else result_reg3 <= r_final_s3_comb;
  end

  assign result_out = result_reg3;

endmodule
