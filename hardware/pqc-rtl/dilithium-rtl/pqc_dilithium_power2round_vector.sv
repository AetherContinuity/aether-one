// pqc_dilithium_power2round_vector.sv
//
// M5-DILITHIUM-001 DK4: Power2Round koko t-vektorille (K=6 polynomia,
// 256 kerrointa/polynomi). Taysin rinnakkainen, kombinatorinen -
// silmukoi todistetun pqc_dilithium_power2round.sv:n K*256=1536 kertaa
// generate-lohkolla.

`timescale 1ns/1ps

module pqc_dilithium_power2round_vector #(
    parameter int Q = 8380417,
    parameter int CW = 23,
    parameter int D = 13,
    parameter int K = 6
)(
    input  logic [K*256*CW-1:0] t_in_flat,
    output logic [K*256*(CW-D)-1:0] t1_out_flat,
    output logic [K*256*CW-1:0] t0_out_flat  // etumerkillinen, tallennettu CW-bittisena (sign-extended)
);

  genvar gi, gj;
  generate
    for (gi = 0; gi < K; gi++) begin : g_row
      for (gj = 0; gj < 256; gj++) begin : g_coeff
        logic [CW-D-1:0] r1_w;
        logic signed [CW-1:0] r0_w;
        pqc_dilithium_power2round #(.Q(Q), .CW(CW), .D(D)) p2r_dut (
          .c_in(t_in_flat[(gi*256+gj)*CW +: CW]),
          .r1_out(r1_w),
          .r0_out(r0_w)
        );
        assign t1_out_flat[(gi*256+gj)*(CW-D) +: (CW-D)] = r1_w;
        assign t0_out_flat[(gi*256+gj)*CW +: CW] = r0_w;
      end
    end
  endgenerate

endmodule
