// pqc_dilithium_unpack_z_vector.sv
//
// M5-DILITHIUM-001 DK5: bit_unpack_z koko z-vektorille (L=5
// polynomia). Silmukoi todistetun pqc_dilithium_unpack_z.sv:n L
// kertaa generate-lohkolla.

`timescale 1ns/1ps

module pqc_dilithium_unpack_z_vector #(
    parameter int GAMMA1 = 524288,
    parameter int ZW = 24,
    parameter int L = 5
)(
    input  logic [L*256*20-1:0] packed_in,
    output logic [L*256*ZW-1:0] z_out_flat
);

  genvar gi;
  generate
    for (gi = 0; gi < L; gi++) begin : g_poly
      pqc_dilithium_unpack_z #(.GAMMA1(GAMMA1), .ZW(ZW)) unpack_dut (
        .packed_in(packed_in[gi*256*20 +: 256*20]),
        .z_out_flat(z_out_flat[gi*256*ZW +: 256*ZW])
      );
    end
  endgenerate

endmodule
