// pqc_dilithium_ntt_gs_butterfly.sv
//
// M5-DILITHIUM-001 DK1: Gentleman-Sande-butterfly ML-DSA:n inverse-
// NTT:lle (Q=8380417). ERI rakenne kuin forward-NTT:n Cooley-Tukey-
// butterfly (pqc_dilithium_ntt_butterfly.sv):
//
//   t = a
//   a_out = t + b               (mod Q)
//   b_out = (t - b) * zeta      (mod Q) - HUOM: kertolasku VASTA
//           vahennyksen JALKEEN, toisin kuin forward-butterflyssa
//           jossa kertolasku tapahtuu ENNEN yhteen-/vahennyslaskua.
//
// zeta_in on JO negatoitu ja siirretty positiiviseksi edustajaksi
// (Q - zetas[k]) mod Q generointivaiheessa (Python-puolella) - RTL
// ei tee omaa negaatiota, vain kayttaa annettua zeta-arvoa suoraan.

`timescale 1ns/1ps

module pqc_dilithium_ntt_gs_butterfly #(
    parameter int Q = 8380417,
    parameter int CW = 23
)(
    input  logic [CW-1:0] a_in,
    input  logic [CW-1:0] b_in,
    input  logic [CW-1:0] zeta_in,   // jo negatoitu, positiivinen edustaja
    output logic [CW-1:0] a_out,
    output logic [CW-1:0] b_out
);

  logic [CW:0] a_plus_b;
  logic signed [CW:0] a_minus_b_signed;
  logic [CW-1:0] a_minus_b_pos;  // (t-b) mod Q, positiivinen edustaja

  assign a_plus_b = {1'b0, a_in} + {1'b0, b_in};
  assign a_out = (a_plus_b >= Q) ? (a_plus_b - Q) : a_plus_b[CW-1:0];

  assign a_minus_b_signed = $signed({1'b0, a_in}) - $signed({1'b0, b_in});
  assign a_minus_b_pos = (a_minus_b_signed < 0) ? (a_minus_b_signed + Q) : a_minus_b_signed[CW-1:0];

  pqc_dilithium_barrett_mulmod #(.Q(Q)) mulmod_dut (
    .a_in(a_minus_b_pos), .b_in(zeta_in), .result_out(b_out)
  );

endmodule
