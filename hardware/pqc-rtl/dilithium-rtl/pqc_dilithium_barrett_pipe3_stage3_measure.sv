// SYNTH-002: Barrett-pipeline (3-vaihe) vaihe 3 eristettynä ltp-mittausta varten.
module pqc_dilithium_barrett_pipe3_stage3_measure #(
    parameter int Q = 8380417,
    parameter int CW = 23
)(
    input  logic [2*CW-1:0] product_in,
    input  logic [23:0] q_est_in,
    output logic [CW-1:0] result_out
);
  logic [46:0] q_est_times_q_comb;
  logic [46:0] r_wide_comb;
  assign q_est_times_q_comb = q_est_in * Q;
  assign r_wide_comb = {1'b0, product_in} - q_est_times_q_comb;
  assign result_out = (r_wide_comb >= Q) ? (r_wide_comb - Q) : r_wide_comb[CW-1:0];
endmodule
