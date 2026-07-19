// pqc_dilithium_sign_challenge.sv
//
// M5-DILITHIUM-001 DK6 S4: Challenge-generointi.
//   w1 = HighBits(w, alpha)          [= Decompose:n oma r1-ulostulo]
//   w1_bytes = bit_pack_w(w1)        [jo todistettu]
//   c_tilde = H(mu||w1_bytes, 48)    [SHAKE256]
//   c = SampleInBall(c_tilde, TAU)   [jo todistettu]
//
// HighBits on TAYSIN SUORA Decompose:n r1-ulostulo (ks.
// dilithium_py/utilities/utils.py: high_bits(r,a,q)=decompose(r,a,q)[0])
// - EI omaa erillista logiikkaa, VAIN K*256 rinnakkaista Decompose-
// instanssia (kombinatorinen, ei kelloa tarvita).

`timescale 1ns/1ps

module pqc_dilithium_sign_challenge #(
    parameter int Q = 8380417,
    parameter int CW = 23,
    parameter int K = 6,
    parameter int TAU = 49,
    parameter int ALPHA = 523776  // 2*GAMMA2
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [K*256*CW-1:0] w_in_flat,
    input  logic [511:0] mu_in,

    output logic done,
    output logic [383:0] c_tilde_out,
    output logic [256*8-1:0] c_out_flat
);

  // --- w1 = HighBits(w) jokaiselle K*256 kertoimelle (rinnakkainen) ---
  logic [K*256*4-1:0] w1_flat;
  genvar gwi, gwj;
  generate
    for (gwi = 0; gwi < K; gwi++) begin : g_w1_row
      for (gwj = 0; gwj < 256; gwj++) begin : g_w1_coeff
        logic [3:0] r1_w;
        logic signed [CW-1:0] r0_w;
        pqc_dilithium_decompose #(.Q(Q), .CW(CW), .ALPHA(ALPHA)) decomp_dut (
          .r_in(w_in_flat[(gwi*256+gwj)*CW +: CW]),
          .r1_out(r1_w), .r0_out(r0_w)
        );
        assign w1_flat[(gwi*256+gwj)*4 +: 4] = r1_w;
      end
    end
  endgenerate

  // --- bit_pack_w(w1) ---
  logic [8*K*128-1:0] w1_bytes;
  pqc_dilithium_pack_w #(.K(K)) pack_w_dut (
    .w_prime_in_flat(w1_flat), .w_prime_packed_out(w1_bytes)
  );

  // --- c_tilde = SHAKE256(mu||w1_bytes, 48) ---
  logic shake_start, shake_done;
  logic [8*136*7-1:0] shake_msg_in;
  logic [8*48-1:0] shake_out;
  pqc_shake256 #(.MAX_BLOCKS(7), .MAX_OUT_BYTES(48)) shake_dut (
    .clk(clk), .reset(reset), .start(shake_start),
    .msg_in(shake_msg_in), .msg_len_bytes(16'(64+K*128)), .out_len_bytes(16'd48),
    .out_data(shake_out), .done(shake_done)
  );

  // --- c = SampleInBall(c_tilde, TAU) ---
  logic sib_start, sib_done, sib_exhausted;
  pqc_dilithium_sample_in_ball #(.TAU(TAU)) sib_dut (
    .clk(clk), .reset(reset), .start(sib_start),
    .c_tilde_in(c_tilde_out), .done(sib_done), .error_exhausted(sib_exhausted), .coeffs_out_flat(c_out_flat)
  );

  typedef enum logic [2:0] { S_IDLE, S_START_SHAKE, S_WAIT_SHAKE, S_START_SIB, S_WAIT_SIB, S_DONE } state_e;
  state_e state;

  always_ff @(posedge clk) begin
    shake_start <= 1'b0;
    sib_start <= 1'b0;
    done <= 1'b0;

    if (reset) begin
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: if (start) begin
          shake_msg_in <= '0;
          shake_msg_in[511:0] <= mu_in;
          shake_msg_in[8*(64+K*128)-1:512] <= w1_bytes;
          state <= S_START_SHAKE;
        end

        S_START_SHAKE: begin
          shake_start <= 1'b1;
          state <= S_WAIT_SHAKE;
        end

        S_WAIT_SHAKE: if (shake_done) begin
          c_tilde_out <= shake_out;
          state <= S_START_SIB;
        end

        S_START_SIB: begin
          sib_start <= 1'b1;
          state <= S_WAIT_SIB;
        end

        S_WAIT_SIB: if (sib_done) state <= S_DONE;

        S_DONE: begin
          done <= 1'b1;
          state <= S_IDLE;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule
