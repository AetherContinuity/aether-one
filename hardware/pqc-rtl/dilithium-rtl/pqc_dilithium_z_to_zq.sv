// pqc_dilithium_z_to_zq.sv
//
// M5-DILITHIUM-001 DK5: z:n etumerkillisesta (24-bittinen) Zq-
// edustajaksi ([0,Q)) muunnos, koko L-vektorille. ERILLINEN moduuli
// (EI top-level-generate) - havaittu etta inline top-level-generate
// tassa TAYSIN samassa laskennassa aiheutti simulaattorin oman
// jumin YHDISTETTYNA muihin moduuleihin (ks. debug-loydos
// 2026-07-19), vaikka SAMA laskenta ERILLISENA MODUULINA toimii
// moitteettomasti.

`timescale 1ns/1ps

module pqc_dilithium_z_to_zq #(
    parameter int Q = 8380417,
    parameter int CW = 23,
    parameter int L = 5
)(
    input  logic [L*256*24-1:0] z_wide_in,   // etumerkillinen, 24-bittinen (unpack_z_vector:n oma ulostulo)
    output logic [L*256*CW-1:0] z_zq_out
);

  genvar gi;
  generate
    for (gi = 0; gi < L*256; gi++) begin : g_coeff
      wire signed [23:0] raw = z_wide_in[gi*24 +: 24];
      assign z_zq_out[gi*CW +: CW] = (raw < 0) ? (Q + raw) : raw[CW-1:0];
    end
  endgenerate

endmodule
