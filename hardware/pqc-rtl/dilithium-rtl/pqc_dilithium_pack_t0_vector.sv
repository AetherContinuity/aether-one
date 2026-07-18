// pqc_dilithium_pack_t0_vector.sv
//
// M5-DILITHIUM-001 DK4: bit_pack_t0 koko t0-vektorille (K=6
// polynomia). Silmukoi todistetun pqc_dilithium_pack_t0.sv:n K
// kertaa generate-lohkolla.

`timescale 1ns/1ps

module pqc_dilithium_pack_t0_vector #(
    parameter int CW = 23,
    parameter int K = 6
)(
    input  logic [K*256*CW-1:0] t0_in_flat,
    output logic [K*256*13-1:0] t0_packed_out
);

  genvar gi;
  generate
    for (gi = 0; gi < K; gi++) begin : g_row
      pqc_dilithium_pack_t0 #(.CW(CW)) pack_dut (
        .t0_in_flat(t0_in_flat[gi*256*CW +: 256*CW]),
        .packed_out(t0_packed_out[gi*256*13 +: 256*13])
      );
    end
  endgenerate

endmodule
