// pqc_dilithium_barrett_mulmod_pipe2.sv
//
// SYNTH-001: 2-vaiheinen REKISTEROITU versio pqc_dilithium_barrett_
// mulmod.sv:sta. SAMA algoritmi, SAMA funktionaalinen tulos - AINOA
// ero on etta laskuketju on jaettu YHDELLA rekisterirajalla kahteen
// vaiheeseen, jotta yksittaisen kellojakson looginen kriittinen polku
// lyhenee (baseline: 107 tasoa taysin kombinatorisena, ks.
// SYNTH-001-barrett-pipeline.md).
//
// VAIHE 1 (syotto -> rekisteri): product = a*b; q_est = (product*M)>>K.
//   Rekisteroidaan SEKA product etta q_est (product tarvitaan viela
//   vaiheessa 2 vahennykseen).
// VAIHE 2 (rekisteri -> ulostulo): q_est_times_q = q_est*Q;
//   r_wide = product - q_est_times_q; ehdollinen loppuvahennys.
//
// KIINTEA 2 syklin latenssi (start->valid), EI valiaikaista start/done
// -kasittelya monimutkaisemmalle FSM-integraatiolle - tama on
// TAHALLAAN yksinkertainen "syota sisaan, odota 2 syklia, lue ulos"
// -rajapinta, sopien suoraviivaisesti mihin tahansa kutsuvaan FSM:aan
// joka jo osaa odottaa N sykleaa (sama kuvio kuin muut taman projektin
// sekventiaaliset alimoduulit).

`timescale 1ns/1ps

module pqc_dilithium_barrett_mulmod_pipe2 #(
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

  // --- VAIHE 1: kombinatorinen osa ---
  logic [2*CW-1:0] product_comb;
  logic [2*CW+24-1:0] product_times_m_comb;
  logic [23:0] q_est_comb;

  assign product_comb = a_in * b_in;
  assign product_times_m_comb = product_comb * M_CONST;
  assign q_est_comb = product_times_m_comb[2*CW+24-1:K_SHIFT];

  // --- Rekisteriraja (VAIHE 1 -> VAIHE 2) ---
  logic [2*CW-1:0] product_reg;
  logic [23:0] q_est_reg;

  always_ff @(posedge clk) begin
    if (reset) begin
      product_reg <= '0;
      q_est_reg <= '0;
    end else begin
      product_reg <= product_comb;
      q_est_reg <= q_est_comb;
    end
  end

  // --- VAIHE 2: kombinatorinen osa ---
  logic [46:0] q_est_times_q_comb;
  logic [46:0] r_wide_comb;
  logic [CW-1:0] r_final_comb;

  assign q_est_times_q_comb = q_est_reg * Q;
  assign r_wide_comb = {1'b0, product_reg} - q_est_times_q_comb;
  assign r_final_comb = (r_wide_comb >= Q) ? (r_wide_comb - Q) : r_wide_comb[CW-1:0];

  // --- Ulostulorekisteri (VAIHE 2:n oma tulos) ---
  logic [CW-1:0] result_reg;
  always_ff @(posedge clk) begin
    if (reset) result_reg <= '0;
    else result_reg <= r_final_comb;
  end

  assign result_out = result_reg;

endmodule
