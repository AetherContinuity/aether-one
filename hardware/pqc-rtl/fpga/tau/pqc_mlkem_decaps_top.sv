// pqc_mlkem_decaps_top.sv
//
// M4-DECAPS-ORCH-001: yhdistaa Phase A+G (pqc_mlkem_decaps_a_core)
// ja Phase B1-B4 (pqc_mlkem_decaps_b1_core) TAYDEKSI ML-KEM.
// Decaps_internal-orkestroinniksi. Sekvenssi: kaynnista Phase A+G,
// odota valmis, kaynnista Phase B (kayttaen A+G:n omaa m'/K'/r'-
// tulosta), odota valmis, tuota lopullinen K_final.
//
// dk-syote puretaan tassa moduulissa dkPKE (768B) + ek (800B, dk:n
// oma sisainen ek-kopio) + h (32B) + z (32B) - FIPS 203:n oman
// dk-rakenteen mukaisesti: dk = dkPKE || ek || H(ek) || z.

`timescale 1ns/1ps

module pqc_mlkem_decaps_top #(
    parameter int COEFF_W = 16,
    parameter int SPAD_AW = 9,
    parameter int K = 2
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [8*768-1:0] c_in,     // alkuperainen siffertext
    input  logic [8*1632-1:0] dk_in,   // dk = dkPKE(768B)||ek(800B)||h(32B)||z(32B)

    output logic done,
    output logic [255:0] K_final_out,
    output logic match_out
);

  // --- dk:n oma purku FIPS 203:n rakenteen mukaisesti ---
  wire [8*768-1:0] dkPKE = dk_in[8*768-1:0];
  wire [8*800-1:0] ek    = dk_in[8*(768+800)-1:8*768];
  wire [255:0] h_val     = dk_in[8*(768+800+32)-1:8*(768+800)];
  wire [255:0] z_val     = dk_in[8*1632-1:8*(768+800+32)];

  // --- Phase A+G ---
  logic phaseA_start, phaseA_done;
  logic [255:0] m_prime, K_prime, r_prime;

  pqc_mlkem_decaps_a_core #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW), .K(K)) decaps_a (
    .clk(clk), .reset(reset), .start(phaseA_start),
    .c_in(c_in), .dkPKE_in(dkPKE), .h_in(h_val),
    .done(phaseA_done), .m_prime_out(m_prime),
    .K_prime_out(K_prime), .r_prime_out(r_prime)
  );

  // --- Phase B1-B4 ---
  logic phaseB_start, phaseB_done;
  logic [4*256*COEFF_W-1:0] unused_A;
  logic [K*256*COEFF_W-1:0] unused_yvec, unused_yhat, unused_e1vec, unused_uacc, unused_uvec;
  logic [256*COEFF_W-1:0] unused_e2, unused_vacc, unused_vpoly;
  logic [8*768-1:0] unused_cprime;

  pqc_mlkem_decaps_b1_core #(.COEFF_W(COEFF_W), .K(K)) decaps_b (
    .clk(clk), .reset(reset), .start(phaseB_start),
    .ek_in(ek), .r_prime_in(r_prime), .m_prime_in(m_prime),
    .c_in(c_in), .z_in(z_val), .K_prime_in(K_prime),
    .done(phaseB_done),
    .A_out_flat(unused_A), .y_vec_out_flat(unused_yvec), .y_hat_out_flat(unused_yhat),
    .e1_vec_out_flat(unused_e1vec), .e2_poly_out(unused_e2),
    .u_acc_out_flat(unused_uacc), .v_acc_out(unused_vacc),
    .u_vec_out_flat(unused_uvec), .v_poly_out(unused_vpoly),
    .c_prime_out(unused_cprime),
    .match_out(match_out), .K_final_out(K_final_out)
  );

  typedef enum logic [2:0] {S_IDLE, S_START_A, S_WAIT_A, S_START_B, S_WAIT_B, S_DONE} state_e;
  state_e state;

  always_ff @(posedge clk) begin
    phaseA_start <= 1'b0;
    phaseB_start <= 1'b0;
    done <= 1'b0;

    if (reset) begin
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: if (start) begin
          phaseA_start <= 1'b1;
          state <= S_WAIT_A;
        end

        S_WAIT_A: if (phaseA_done) begin
          phaseB_start <= 1'b1;
          state <= S_WAIT_B;
        end

        S_WAIT_B: if (phaseB_done) begin
          state <= S_DONE;
        end

        S_DONE: begin
          done <= 1'b1;
          state <= S_IDLE;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule
