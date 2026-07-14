// pqc_shake256.sv
//
// M3 Issue #14, Vaihe A/B: SHAKE256, sama uusi kayttaytymisero kuin
// SHAKE128:lla (Issue #12/#13:een verrattuna) - MUUTTUVA ulostulopituus
// (XOF). rate=136 tavua (1088 bittia, capacity=512 bittia),
// domain-suffiksi=0x1F (EI 0x06).
//
// out_len_bytes on AJONAIKAINEN portti (ei kiintea parametri kuten
// SHA3-256/512:ssa) - tama on SHAKE:n oma keskeinen ominaisuus.
// MAX_OUT_BYTES=512 riittaa testaamaan useita squeeze-kierroksia
// (512/168 = 3,05 -> 4 kierrosta tarvitaan pisimmalle testitapaukselle).

`timescale 1ns/1ps

module pqc_shake256 #(
    parameter int MAX_BLOCKS    = 2,
    parameter int MAX_OUT_BYTES = 512
)(
    input  logic clk,
    input  logic reset,
    input  logic start,
    input  logic [8*136*MAX_BLOCKS-1:0] msg_in,
    input  logic [15:0] msg_len_bytes,
    input  logic [15:0] out_len_bytes,
    output logic [8*MAX_OUT_BYTES-1:0] out_data,
    output logic done
);

  localparam int RATE_BYTES = 136;

  typedef enum logic [1:0] {S_IDLE, S_PAD, S_ABSORB, S_SQUEEZE} state_e;
  state_e fsm_state;

  logic [8*RATE_BYTES*MAX_BLOCKS-1:0] padded_msg;
  logic [7:0] num_blocks;

  pqc_keccak_pad #(.RATE_BYTES(RATE_BYTES), .MAX_BLOCKS(MAX_BLOCKS), .DOMAIN_SUFFIX(8'h1F)) pad_dut (
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

  pqc_keccak_squeeze #(.RATE_BYTES(RATE_BYTES), .MAX_OUT_BYTES(MAX_OUT_BYTES)) squeeze_dut (
    .clk(clk), .reset(reset), .start(squeeze_start),
    .state_in(absorbed_state), .out_len_bytes(out_len_bytes),
    .out_data(out_data), .done(squeeze_done)
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

endmodule
