// pqc_dilithium_ntt_butterfly.sv
//
// M5-DILITHIUM-001 DK1: yksittainen Cooley-Tukey-butterfly ML-DSA:n
// NTT:lle (Q=8380417). Uudelleenkayttaa suoraan jo todistetun
// pqc_dilithium_barrett_mulmod.sv:n zeta*b-kertolaskuun.
//
// FIPS 204 / dilithium-py:n oma to_ntt()-kaava:
//   t = zeta * coeffs[j+l]
//   coeffs[j+l] = coeffs[j] - t
//   coeffs[j]   = coeffs[j] + t
//
// HUOM: a+t voi ylittaa Q (max 2Q-2, mahtuu 24 bittiin) - yksi
// ehdollinen vahennys riittaa. a-t voi olla NEGATIIVINEN (min -(Q-1))
// - taman kasittely vaatii ETUMERKITYN valiarvon ja ehdollisen
// LISAYKSEN (Q lisataan jos tulos negatiivinen), EI vahennyksen.
// Tama on TASMALLEEN se kohta jossa rvv-dilithium:n oma README
// mainitsee etumerkkikonvention sekaantuneen ohjelmistopuolella -
// tassa sovelletaan huolellista, eksplisiittista etumerkin-
// kasittelya kombinatorisena logiikkana valttaen saman sudenkuopan.

`timescale 1ns/1ps

module pqc_dilithium_ntt_butterfly #(
    parameter int Q = 8380417,
    parameter int CW = 23
)(
    input  logic [CW-1:0] a_in,     // coeffs[j]
    input  logic [CW-1:0] b_in,     // coeffs[j+l]
    input  logic [CW-1:0] zeta_in,
    output logic [CW-1:0] a_out,    // coeffs[j] (paivitetty)
    output logic [CW-1:0] b_out     // coeffs[j+l] (paivitetty)
);

  logic [CW-1:0] t;
  pqc_dilithium_barrett_mulmod #(.Q(Q)) mulmod_dut (
    .a_in(zeta_in), .b_in(b_in), .result_out(t)
  );

  logic [CW:0] a_plus_t;    // max (Q-1)+(Q-1) = 2Q-2, tarvitsee CW+1 bittia
  logic signed [CW:0] a_minus_t;  // etumerkillinen, min -(Q-1)

  assign a_plus_t = {1'b0, a_in} + {1'b0, t};
  assign a_minus_t = $signed({1'b0, a_in}) - $signed({1'b0, t});

  // a+t: yksi ehdollinen vahennys riittaa (tulos jo ei-negatiivinen)
  // -> taman kaavan mukaan TAMA on coeffs[j] = a_out
  assign a_out = (a_plus_t >= Q) ? (a_plus_t - Q) : a_plus_t[CW-1:0];

  // a-t: etumerkillinen tulos, LISATAAN Q jos negatiivinen (EI
  // vahenneta - tama on juuri se etumerkkikonventio joka pitaa pitaa
  // oikeinpain) -> TAMA on coeffs[j+l] = b_out
  assign b_out = (a_minus_t < 0) ? (a_minus_t + Q) : a_minus_t[CW-1:0];

endmodule
