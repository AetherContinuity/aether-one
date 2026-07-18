// pqc_dilithium_pack_dk.sv
//
// M5-DILITHIUM-001 DK4: dk:n lopullinen kokoonpano.
// dk = rho(32) || K(32) || tr(64) || bit_pack_s(s1) || bit_pack_s(s2)
//      || bit_pack_t0(t0)
// tr = H(ek,64) = SHA3-512(ek) - kayttaa suoraan jo todistettua
// pqc_sha3_512.sv-ydinta.

`timescale 1ns/1ps

module pqc_dilithium_pack_dk #(
    parameter int K = 6,
    parameter int L = 5
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [255:0] rho_in,
    input  logic [255:0] K_in,          // dk:n oma K-avain (32 tavua)
    input  logic [8*(32+K*320)-1:0] ek_in,  // 1952 tavua (H:n oma syote)
    input  logic [L*8*128-1:0] s1_packed_in,
    input  logic [K*8*128-1:0] s2_packed_in,
    input  logic [K*256*13-1:0] t0_packed_in,

    output logic done,
    output logic [8*(32+32+64+L*128+K*128+K*416)-1:0] dk_out  // 4032 tavua K=6,L=5:lle
);

  logic sha_start, sha_done;
  logic [8*72*28-1:0] sha_msg_in;  // 1952 tavua, SHA3-512:n oma rate=72 tavua/lohko -> 28 lohkoa
  logic [511:0] sha_out;
  pqc_sha3_512 #(.MAX_BLOCKS(28)) sha_dut (
    .clk(clk), .reset(reset), .start(sha_start),
    .msg_in(sha_msg_in), .msg_len_bytes(16'd1952),
    .digest_out(sha_out), .done(sha_done)
  );

  typedef enum logic [1:0] { S_IDLE, S_START_SHA, S_WAIT_SHA, S_DONE } state_e;
  state_e state;

  always_ff @(posedge clk) begin
    sha_start <= 1'b0;
    done <= 1'b0;

    if (reset) begin
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: if (start) begin
          sha_msg_in <= '0;
          sha_msg_in[8*(32+K*320)-1:0] <= ek_in;
          state <= S_START_SHA;
        end

        S_START_SHA: begin
          sha_start <= 1'b1;
          state <= S_WAIT_SHA;
        end

        S_WAIT_SHA: if (sha_done) state <= S_DONE;

        S_DONE: begin
          done <= 1'b1;
          state <= S_IDLE;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

  // --- Lopullinen kokoonpano: rho||K||tr||s1||s2||t0 (pack_bytes-
  // konventio: rho ALIMMAT tavut) ---
  assign dk_out = {t0_packed_in, s2_packed_in, s1_packed_in, sha_out, K_in, rho_in};

endmodule
