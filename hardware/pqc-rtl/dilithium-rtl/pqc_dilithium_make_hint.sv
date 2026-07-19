// pqc_dilithium_make_hint.sv
//
// M5-DILITHIUM-001 DK6 S6: MakeHint (FIPS 204 Algoritmi 39), yksi
// kerroin. Kayttaa suoraan jo todistettua pqc_dilithium_decompose.sv:n
// (HighBits=Decompose:n oma r1-ulostulo).
//
// dilithium-py:n oma kaava: r1=HighBits(r,alpha,Q); v1=HighBits(r+z,
// alpha,Q); return (r1!=v1). TOTEUTETTU TASMALLEEN taman mukaisesti
// (EI algebrallista sievennysta, valttaen oman virheen riski).

`timescale 1ns/1ps

module pqc_dilithium_make_hint #(
    parameter int Q = 8380417,
    parameter int CW = 23,
    parameter int ALPHA = 523776
)(
    input  logic [CW-1:0] z_in,   // etumerkillinen arvo, Zq-edustajana [0,Q) annettuna
    input  logic [CW-1:0] r_in,   // Zq-edustaja [0,Q)
    output logic h_out
);

  logic [3:0] r1_of_r;
  logic signed [CW-1:0] r0_dummy1;
  pqc_dilithium_decompose #(.Q(Q), .CW(CW), .ALPHA(ALPHA)) decomp_r (
    .r_in(r_in), .r1_out(r1_of_r), .r0_out(r0_dummy1)
  );

  // r+z mod Q
  wire [CW:0] sum_wide = {1'b0, r_in} + {1'b0, z_in};
  wire [CW-1:0] r_plus_z = (sum_wide >= Q) ? (sum_wide - Q) : sum_wide[CW-1:0];

  logic [3:0] r1_of_rz;
  logic signed [CW-1:0] r0_dummy2;
  pqc_dilithium_decompose #(.Q(Q), .CW(CW), .ALPHA(ALPHA)) decomp_rz (
    .r_in(r_plus_z), .r1_out(r1_of_rz), .r0_out(r0_dummy2)
  );

  assign h_out = (r1_of_r != r1_of_rz);

endmodule
