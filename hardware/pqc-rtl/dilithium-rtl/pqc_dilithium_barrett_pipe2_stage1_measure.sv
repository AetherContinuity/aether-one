// SYNTH-001: Barrett-pipeline-vaihe 1 ERISTETTYNA, PUHTAASTI
// KOMBINATORISENA moduulina VAIN ltp-mittausta varten (vastaa
// pqc_dilithium_barrett_mulmod_pipe2.sv:n omaa "VAIHE 1: kombinatorinen
// osa" -lohkoa tasmalleen).

module pqc_dilithium_barrett_pipe2_stage1_measure #(
    parameter int Q = 8380417,
    parameter longint M_CONST = 8396807,
    parameter int K_SHIFT = 46,
    parameter int CW = 23
)(
    input  logic [CW-1:0] a_in,
    input  logic [CW-1:0] b_in,
    output logic [2*CW-1:0] product_out,
    output logic [23:0] q_est_out
);

  logic [2*CW-1:0] product_comb;
  logic [2*CW+24-1:0] product_times_m_comb;

  assign product_comb = a_in * b_in;
  assign product_times_m_comb = product_comb * M_CONST;
  assign q_est_out = product_times_m_comb[2*CW+24-1:K_SHIFT];
  assign product_out = product_comb;

endmodule
