// pqc_keccak_absorb.sv
//
// M3 Issue #11, Vaihe B: absorbointi - ajaa pqc_keccak_f1600:aa
// (Issue #10) lohko kerrallaan, XORaten kunkin RATE_BYTES-lohkon
// tilaan ennen permutaatiota. Testataan lohkokohtaisesti golden-
// mallia vastaan (kayttajan oma ehdotus).
//
// Kayttaa VALMIIKSI PEHMENNETTYA viestia (pqc_keccak_pad.sv:n
// ulostuloa) - ei toista pehmennyslogiikkaa (jo testattu Vaihe A:ssa).

`timescale 1ns/1ps

module pqc_keccak_absorb #(
    parameter int RATE_BYTES = 136,
    parameter int MAX_BLOCKS = 2
)(
    input  logic clk,
    input  logic reset,
    input  logic start,
    input  logic [8*RATE_BYTES*MAX_BLOCKS-1:0] padded_msg,
    input  logic [7:0] num_blocks,
    output logic [1599:0] state_out,
    output logic done
);

  typedef enum logic [1:0] {S_IDLE, S_XOR, S_PERMUTE, S_DONE} state_e;
  state_e fsm_state;

  logic [1599:0] acc_state;
  logic [7:0] block_idx;

  logic f1600_start, f1600_done;
  logic [1599:0] f1600_state_in, f1600_state_out;

  pqc_keccak_f1600 f1600_dut (
    .clk(clk), .reset(reset), .start(f1600_start),
    .state_in(f1600_state_in), .state_out(f1600_state_out), .done(f1600_done)
  );

  logic [1599:0] block_padded;

  always_comb begin
    logic [8*RATE_BYTES-1:0] block_bytes;
    block_bytes = padded_msg[block_idx*RATE_BYTES*8 +: RATE_BYTES*8];
    block_padded = '0;
    block_padded[RATE_BYTES*8-1:0] = block_bytes;
  end

  assign f1600_state_in = acc_state ^ block_padded;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      fsm_state   <= S_IDLE;
      done        <= 1'b0;
      block_idx   <= 8'd0;
      acc_state   <= '0;
      f1600_start <= 1'b0;
    end else begin
      f1600_start <= 1'b0;
      case (fsm_state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            acc_state <= '0;
            block_idx <= 8'd0;
            fsm_state <= S_XOR;
          end
        end

        S_XOR: begin
          // f1600_state_in on jo kombinatorisesti acc_state ^ block_padded
          f1600_start <= 1'b1;
          fsm_state   <= S_PERMUTE;
        end

        S_PERMUTE: begin
          if (f1600_done) begin
            acc_state <= f1600_state_out;
            if (block_idx == num_blocks - 1) begin
              fsm_state <= S_DONE;
            end else begin
              block_idx <= block_idx + 8'd1;
              fsm_state <= S_XOR;
            end
          end
        end

        S_DONE: begin
          done <= 1'b1;
          fsm_state <= S_IDLE;
        end

        default: fsm_state <= S_IDLE;
      endcase
    end
  end

  assign state_out = acc_state;

endmodule
