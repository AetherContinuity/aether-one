// pqc_dilithium_pack_s_vector.sv
//
// M5-DILITHIUM-001 DK4: bit_pack_s koko s1 (L=5) ja s2 (K=6)
// -vektoreille. Silmukoi todistetun pqc_dilithium_pack_s.sv:n
// L+K=11 kertaa generate-lohkolla, taysin rinnakkainen.

`timescale 1ns/1ps

module pqc_dilithium_pack_s_vector #(
    parameter int ETA = 4,
    parameter int K = 6,
    parameter int L = 5
)(
    input  logic [L*256*8-1:0] s1_in_flat,
    input  logic [K*256*8-1:0] s2_in_flat,
    output logic [L*8*128-1:0] s1_packed_out,
    output logic [K*8*128-1:0] s2_packed_out
);

  genvar gi;
  generate
    for (gi = 0; gi < L; gi++) begin : g_s1
      pqc_dilithium_pack_s #(.ETA(ETA)) pack_dut (
        .coeffs_in_flat(s1_in_flat[gi*256*8 +: 256*8]),
        .packed_out(s1_packed_out[gi*8*128 +: 8*128])
      );
    end
    for (gi = 0; gi < K; gi++) begin : g_s2
      pqc_dilithium_pack_s #(.ETA(ETA)) pack_dut (
        .coeffs_in_flat(s2_in_flat[gi*256*8 +: 256*8]),
        .packed_out(s2_packed_out[gi*8*128 +: 8*128])
      );
    end
  endgenerate

endmodule
