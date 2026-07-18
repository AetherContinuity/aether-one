// pqc_dilithium_use_hint.sv
//
// M5-DILITHIUM-001 DK5: UseHint (FIPS 204 Algoritmi 40), yksi
// kerroin. Kayttaa suoraan jo todistettua pqc_dilithium_decompose.sv
// -moduulia.
//
// dilithium-py:n oma kaava:
//   m = (Q-1)/ALPHA = 16
//   r1,r0 = decompose(r,ALPHA,Q)
//   jos h==1:
//     jos r0>0: return (r1+1) mod m
//     muuten:   return (r1-1) mod m
//   muuten: return r1

`timescale 1ns/1ps

module pqc_dilithium_use_hint #(
    parameter int Q = 8380417,
    parameter int CW = 23,
    parameter int ALPHA = 523776,
    parameter int M = 16  // (Q-1)/ALPHA
)(
    input  logic h_in,
    input  logic [CW-1:0] r_in,
    output logic [3:0] result_out  // [0,M)
);

  logic [3:0] r1;
  logic signed [CW-1:0] r0;

  pqc_dilithium_decompose #(.Q(Q), .CW(CW), .ALPHA(ALPHA)) decomp_dut (
    .r_in(r_in), .r1_out(r1), .r0_out(r0)
  );

  wire [4:0] r1_plus1_mod  = (r1 == M-1) ? 5'd0 : (r1 + 5'd1);
  wire [4:0] r1_minus1_mod = (r1 == 4'd0) ? (M-1) : (r1 - 4'd1);

  assign result_out = !h_in ? r1 :
                       (r0 > 0) ? r1_plus1_mod[3:0] : r1_minus1_mod[3:0];

endmodule
