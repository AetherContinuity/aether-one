// pqc_dilithium_power2round.sv
//
// M5-DILITHIUM-001 DK4: Power2Round_d (FIPS 204 Algoritmi 35), D=13
// (ML-DSA-65:n oma parametri). Yhden kertoimen kerrallaan, taysin
// kombinatorinen.
//
// dilithium-py:n oma kaava:
//   power_2 = 1 << d  (=8192)
//   r = c mod Q
//   r0 = reduce_mod_pm(r, power_2)  (etumerkillinen, valilla (-4096,4096])
//   r1 = (r - r0) >> d
//
// reduce_mod_pm(r, n) (n=8192, parillinen): r0 = r mod n; jos r0 >
// n/2, r0 -= n. Taten r0 ON JO valilla (-n/2, n/2].

`timescale 1ns/1ps

module pqc_dilithium_power2round #(
    parameter int Q = 8380417,
    parameter int CW = 23,
    parameter int D = 13
)(
    input  logic [CW-1:0] c_in,          // Zq-edustaja [0,Q)
    output logic [CW-D-1:0] r1_out,      // t1: [0, ceil(Q/2^D))
    output logic signed [CW-1:0] r0_out  // t0: etumerkillinen (-4096,4096]
);

  localparam int POW2 = 1 << D;  // 8192

  logic [D-1:0] r0_mod;              // r mod POW2, [0,POW2)
  logic signed [D:0] r0_signed;      // (-4096,4096]
  logic signed [CW:0] c_signed_ext;  // c_in etumerkkilaajennettuna (aina >=0)
  logic signed [CW:0] diff;          // c_in - r0 (aina >=0, jaollinen 2^D:lla)

  assign r0_mod = c_in[D-1:0];   // c_in on jo < Q < 2^23, mod POW2 = alimmat D bittia
  assign r0_signed = (r0_mod > (POW2/2)) ? ($signed({1'b0, r0_mod}) - POW2) : $signed({1'b0, r0_mod});

  assign r0_out = r0_signed;

  assign c_signed_ext = $signed({1'b0, c_in});
  assign diff = c_signed_ext - r0_signed;
  assign r1_out = diff[CW-1:D];  // diff on aina ei-negatiivinen ja jaollinen 2^D:lla, mahtuu CW bittiin

endmodule
