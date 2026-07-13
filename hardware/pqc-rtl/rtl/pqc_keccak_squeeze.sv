// pqc_keccak_squeeze.sv
//
// M3 Issue #11, Vaihe C: puristus (squeeze) - poimii ulostulotavut
// tilasta, ajaen lisapermutaatioita jos tarvitaan enemman kuin yksi
// rate-lohko (SHAKE:n oma tarve - MUUTTUVA ulostulopituus). Testataan
// seka yhden etta useamman lohkon tapaus erikseen (kayttajan oma
// ehdotus).

`timescale 1ns/1ps

module pqc_keccak_squeeze #(
    parameter int RATE_BYTES    = 136,
    parameter int MAX_OUT_BYTES = 200
)(
    input  logic clk,
    input  logic reset,
    input  logic start,
    input  logic [1599:0] state_in,
    input  logic [15:0] out_len_bytes,
    output logic [8*MAX_OUT_BYTES-1:0] out_data,
    output logic done
);

  typedef enum logic [1:0] {S_IDLE, S_EXTRACT, S_PERMUTE, S_DONE} state_e;
  state_e fsm_state;

  logic [1599:0] cur_state;
  logic [15:0] bytes_done;
  int remaining;
  int take;

  logic f1600_start, f1600_done;
  logic [1599:0] f1600_state_in, f1600_state_out;

  pqc_keccak_f1600 f1600_dut (
    .clk(clk), .reset(reset), .start(f1600_start),
    .state_in(f1600_state_in), .state_out(f1600_state_out), .done(f1600_done)
  );

  assign f1600_state_in = cur_state;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      fsm_state   <= S_IDLE;
      done        <= 1'b0;
      bytes_done  <= 16'd0;
      cur_state   <= '0;
      f1600_start <= 1'b0;
      out_data    <= '0;
    end else begin
      f1600_start <= 1'b0;
      case (fsm_state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            cur_state  <= state_in;
            bytes_done <= 16'd0;
            fsm_state  <= S_EXTRACT;
          end
        end

        S_EXTRACT: begin
          // Poimi min(RATE_BYTES, jaljella oleva) tavua nykyisesta
          // tilasta out_data:n oikeaan kohtaan.
          remaining = int'(out_len_bytes) - int'(bytes_done);
          take = (remaining < RATE_BYTES) ? remaining : RATE_BYTES;
          for (int i = 0; i < RATE_BYTES; i++) begin
            if (i < take) begin
              out_data[(int'(bytes_done)+i)*8 +: 8] <= cur_state[i*8 +: 8];
            end
          end
          bytes_done <= bytes_done + take[15:0];

          if (bytes_done + take[15:0] >= out_len_bytes) begin
            fsm_state <= S_DONE;
          end else begin
            f1600_start <= 1'b1;
            fsm_state   <= S_PERMUTE;
          end
        end

        S_PERMUTE: begin
          if (f1600_done) begin
            cur_state <= f1600_state_out;
            fsm_state <= S_EXTRACT;
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

endmodule
