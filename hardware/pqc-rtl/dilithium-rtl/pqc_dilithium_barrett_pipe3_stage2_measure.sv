// SYNTH-002: Barrett-pipeline (3-vaihe) vaihe 2 eristettynä ltp-mittausta varten.
module pqc_dilithium_barrett_pipe3_stage2_measure #(
    parameter longint M_CONST = 8396807,
    parameter int K_SHIFT = 46,
    parameter int CW = 23
)(
    input  logic [2*CW-1:0] product_in,
    output logic [23:0] q_est_out
);
  logic [2*CW+24-1:0] product_times_m_comb;
  assign product_times_m_comb = product_in * M_CONST;
  assign q_est_out = product_times_m_comb[2*CW+24-1:K_SHIFT];
endmodule
