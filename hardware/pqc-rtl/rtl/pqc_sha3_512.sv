// pqc_sha3_512.sv
//
// M3 Issue #13: SHA3-512, parametrisointi SHA3-256:n (Issue #12)
// paalle. rate=72 tavua (576 bittia), capacity=1024 bittia,
// domain-suffiksi=0x06 (sama kuin SHA3-256), kiintea 64 tavun
// ulostulo. EI uutta aritmetiikkaa - sama pad+absorb+squeeze-kehys,
// eri RATE_BYTES-parametri.

`timescale 1ns/1ps

module pqc_sha3_512 #(
    parameter int MAX_BLOCKS = 3
)(
    input  logic clk,
    input  logic reset,
    input  logic start,
    input  logic [8*72*MAX_BLOCKS-1:0] msg_in,
    input  logic [15:0] msg_len_bytes,
    output logic [511:0] digest_out,
    output logic done
);

  localparam int RATE_BYTES = 72;

  typedef enum logic [1:0] {S_IDLE, S_PAD, S_ABSORB, S_SQUEEZE} state_e;
  state_e fsm_state;

  logic [8*RATE_BYTES*MAX_BLOCKS-1:0] padded_msg;
  logic [7:0] num_blocks;

  pqc_keccak_pad #(.RATE_BYTES(RATE_BYTES), .MAX_BLOCKS(MAX_BLOCKS), .DOMAIN_SUFFIX(8'h06)) pad_dut (
    .msg_in(msg_in), .msg_len_bytes(msg_len_bytes),
    .padded_out(padded_msg), .num_blocks(num_blocks)
  );

  logic absorb_start, absorb_done;
  logic [1599:0] absorbed_state;

  pqc_keccak_absorb #(.RATE_BYTES(RATE_BYTES), .MAX_BLOCKS(MAX_BLOCKS)) absorb_dut (
    .clk(clk), .reset(reset), .start(absorb_start),
    .padded_msg(padded_msg), .num_blocks(num_blocks),
    .state_out(absorbed_state), .done(absorb_done)
  );

  logic squeeze_start, squeeze_done;
  logic [8*64-1:0] squeeze_out;

  pqc_keccak_squeeze #(.RATE_BYTES(RATE_BYTES), .MAX_OUT_BYTES(64)) squeeze_dut (
    .clk(clk), .reset(reset), .start(squeeze_start),
    .state_in(absorbed_state), .out_len_bytes(16'd64),
    .out_data(squeeze_out), .done(squeeze_done)
  );

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      fsm_state     <= S_IDLE;
      done          <= 1'b0;
      absorb_start  <= 1'b0;
      squeeze_start <= 1'b0;
    end else begin
      absorb_start  <= 1'b0;
      squeeze_start <= 1'b0;
      case (fsm_state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            fsm_state <= S_PAD;
          end
        end

        S_PAD: begin
          absorb_start <= 1'b1;
          fsm_state    <= S_ABSORB;
        end

        S_ABSORB: begin
          if (absorb_done) begin
            squeeze_start <= 1'b1;
            fsm_state     <= S_SQUEEZE;
          end
        end

        S_SQUEEZE: begin
          if (squeeze_done) begin
            done      <= 1'b1;
            fsm_state <= S_IDLE;
          end
        end

        default: fsm_state <= S_IDLE;
      endcase
    end
  end

  assign digest_out = squeeze_out;

endmodule
