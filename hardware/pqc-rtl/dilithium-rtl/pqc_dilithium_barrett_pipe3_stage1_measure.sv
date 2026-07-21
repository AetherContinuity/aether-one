// SYNTH-002: Barrett-pipeline (3-vaihe) vaihe 1 eristettynä ltp-mittausta varten.
module pqc_dilithium_barrett_pipe3_stage1_measure #(
    parameter int CW = 23
)(
    input  logic [CW-1:0] a_in,
    input  logic [CW-1:0] b_in,
    output logic [2*CW-1:0] product_out
);
  assign product_out = a_in * b_in;
endmodule
