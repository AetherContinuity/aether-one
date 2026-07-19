// pqc_dilithium_pack_z_vector.sv
//
// M5-DILITHIUM-001 DK6 S8: bit_pack_z koko z-vektorille (L=5
// polynomia). Silmukoi todistetun pqc_dilithium_pack_z.sv:n L
// kertaa.

`timescale 1ns/1ps

module pqc_dilithium_pack_z_vector #(
    parameter int GAMMA1 = 524288,
    parameter int ZW = 24,
    parameter int L = 5
)(
    input  logic [L*256*ZW-1:0] z_in_flat,
    output logic [L*256*20-1:0] packed_out
);

  genvar gi;
  generate
    for (gi = 0; gi < L; gi++) begin : g_poly
      pqc_dilithium_pack_z #(.GAMMA1(GAMMA1), .ZW(ZW)) pack_dut (
        .z_in_flat(z_in_flat[gi*256*ZW +: 256*ZW]),
        .packed_out(packed_out[gi*256*20 +: 256*20])
      );
    end
  endgenerate

endmodule
