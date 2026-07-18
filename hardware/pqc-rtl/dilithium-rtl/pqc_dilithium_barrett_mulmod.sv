// pqc_dilithium_barrett_mulmod.sv
//
// M5-DILITHIUM-001 DK1: 23-bittisen kertolaskun modulaarinen
// reduktio Barrett-menetelmalla, Q=8380417 (ML-DSA).
//
// TIETOINEN ARKKITEHTUURIVALINTA: Barrett-reduktio Montgomery-
// domainin SIJAAN. Peruste: rvv-dilithium:n oma dokumentoitu
// bugihistoria (ks. dilithium-golden/M5_DILITHIUM_001_PLAN.md, osio
// 4) loysi "vaaran Montgomery-etumerkkikonvention" KAHDESTI eri
// kohdissa ohjelmistototeutuksessa. Barrett valttaa TAMAN kokonaan -
// arvot pysyvat koko ajan normaalialueella (0..Q-1), ei tarvetta
// muuntaa Montgomery-domainiin/-domainista, eika etumerkkikonventiota
// jota voisi sekoittaa.
//
// Barrett-parametrit (vahvistettu Pythonilla 100000 satunnaisella
// parilla, 0 virhetta): k=46, m=floor(2^46/Q)=8396807.
//
// TAYSIN KOMBINATORINEN (sama periaate kuin pqc_compress.sv,
// pqc_multiplyntts.sv jne - rekisterointi tapahtuu kutsuvassa
// tilakoneessa, ei tassa moduulissa).

`timescale 1ns/1ps

module pqc_dilithium_barrett_mulmod #(
    parameter int Q = 8380417,
    parameter longint M_CONST = 8396807,  // floor(2^46/Q)
    parameter int K_SHIFT = 46,
    parameter int CW = 23  // kertoimen bittileveys (0..Q-1 mahtuu 23 bittiin)
)(
    input  logic [CW-1:0] a_in,
    input  logic [CW-1:0] b_in,
    output logic [CW-1:0] result_out
);

  logic [2*CW-1:0] product;          // a*b, max 46 bittia
  logic [2*CW+24-1:0] product_times_m; // product*m, max 70 bittia
  logic [23:0] q_est;                  // (product*m) >> 46, max 24 bittia
  logic [46:0] q_est_times_q;          // q_est*Q, max 47 bittia
  logic [46:0] r_wide;                 // product - q_est*Q (etumerkitta, Barrett takaa etta product >= q_est*Q)
  logic [CW-1:0] r_final;

  assign product = a_in * b_in;
  assign product_times_m = product * M_CONST;
  assign q_est = product_times_m[2*CW+24-1:K_SHIFT];
  assign q_est_times_q = q_est * Q;
  assign r_wide = {1'b0, product} - q_est_times_q;
  // Barrett-tulos on valilla [0, 2Q) - yksi ehdollinen vahennys riittaa
  assign r_final = (r_wide >= Q) ? (r_wide - Q) : r_wide[CW-1:0];
  assign result_out = r_final;

endmodule
