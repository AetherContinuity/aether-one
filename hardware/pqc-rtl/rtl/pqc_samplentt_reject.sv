// pqc_samplentt_reject.sv
//
// M3 Issue #15, Vaihe 2: SampleNTT:n hylkaysnaytteenotto-osuus (FIPS
// 203 Algoritmi 7, rivit 3-16) - kayttaa VALMIIKSI LASKETTUA XOF-
// ulostuloa (pqc_shake128:n omaa, Issue #14). Iteratiivinen, yksi
// 3-tavun ryhma tarkistetaan per sykli.
//
// Instrumentoitu kayttajan oman ohjeen mukaisesti: paitsi lopullinen
// 256 kertoimen taulukko, myos hyvaksyttyjen/hylattyjen maara ja
// kulutetut XOF-tavut.
//
// SUUNNITTELU: yksi puhdas kombinatorinen lohko laskee "seuraavan
// tilan" (next_j, mitka arvot kirjoitetaan a_hat:iin) suoraan
// Algoritmi 7:n omaa rakennetta vastaan (kaksi eri if-lohkoa d1:lle
// ja d2:lle, TASMALLEEN kuten golden-mallissa).

`timescale 1ns/1ps

module pqc_samplentt_reject #(
    parameter int XOF_BYTES = 1008,
    parameter int Q         = 3329
)(
    input  logic clk,
    input  logic reset,
    input  logic start,
    input  logic [8*XOF_BYTES-1:0] xof_data,
    output logic [16*256-1:0] a_hat,
    output logic [15:0] accepted_count,
    output logic [15:0] rejected_count,
    output logic [15:0] xof_bytes_consumed,
    output logic done,
    output logic error_exhausted
);

  typedef enum logic [1:0] {S_IDLE, S_STEP, S_DONE, S_ERROR} state_e;
  state_e fsm_state;

  logic [15:0] byte_idx;
  logic [15:0] j_count;

  logic [7:0] C0, C1, C2;
  logic [11:0] d1, d2;
  logic d1_ok, d2_ok;

  assign C0 = xof_data[byte_idx*8 +: 8];
  assign C1 = xof_data[(byte_idx+1)*8 +: 8];
  assign C2 = xof_data[(byte_idx+2)*8 +: 8];
  assign d1 = {4'b0, C0} + (16'd256 * (12'({4'b0,C1}) % 16'd16));
  assign d2 = (12'({4'b0,C1}) / 16'd16) + (16'd16 * 12'({4'b0,C2}));
  assign d1_ok = (d1 < Q[11:0]);
  assign d2_ok = (d2 < Q[11:0]);

  logic [15:0] j_after_d1;
  logic [15:0] j_after_d2;
  logic write_d1, write_d2;
  logic [15:0] d1_write_idx, d2_write_idx;

  always_comb begin
    j_after_d1 = j_count;
    write_d1 = 1'b0;
    d1_write_idx = j_count;
    if (d1_ok) begin
      write_d1 = 1'b1;
      d1_write_idx = j_count;
      j_after_d1 = j_count + 16'd1;
    end

    j_after_d2 = j_after_d1;
    write_d2 = 1'b0;
    d2_write_idx = j_after_d1;
    if (d2_ok && (j_after_d1 < 16'd256)) begin
      write_d2 = 1'b1;
      d2_write_idx = j_after_d1;
      j_after_d2 = j_after_d1 + 16'd1;
    end
  end

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      fsm_state           <= S_IDLE;
      done                <= 1'b0;
      error_exhausted     <= 1'b0;
      byte_idx            <= 16'd0;
      j_count             <= 16'd0;
      accepted_count      <= 16'd0;
      rejected_count      <= 16'd0;
      xof_bytes_consumed  <= 16'd0;
    end else begin
      case (fsm_state)
        S_IDLE: begin
          done <= 1'b0;
          error_exhausted <= 1'b0;
          if (start) begin
            byte_idx       <= 16'd0;
            j_count        <= 16'd0;
            accepted_count <= 16'd0;
            rejected_count <= 16'd0;
            fsm_state      <= S_STEP;
          end
        end

        S_STEP: begin
          if (byte_idx + 16'd3 > XOF_BYTES[15:0]) begin
            fsm_state <= S_ERROR;
          end else begin
            if (write_d1) a_hat[d1_write_idx*16 +: 16] <= {4'b0, d1};
            if (write_d2) a_hat[d2_write_idx*16 +: 16] <= {4'b0, d2};

            accepted_count <= accepted_count + (write_d1 ? 16'd1 : 16'd0) + (write_d2 ? 16'd1 : 16'd0);
            rejected_count <= rejected_count + (!d1_ok ? 16'd1 : 16'd0) + (!d2_ok ? 16'd1 : 16'd0);

            j_count  <= j_after_d2;
            byte_idx <= byte_idx + 16'd3;

            if (j_after_d2 >= 16'd256) begin
              fsm_state <= S_DONE;
            end
          end
        end

        S_DONE: begin
          done <= 1'b1;
          xof_bytes_consumed <= byte_idx;
          fsm_state <= S_IDLE;
        end

        S_ERROR: begin
          error_exhausted <= 1'b1;
          done <= 1'b1;
          xof_bytes_consumed <= byte_idx;
          fsm_state <= S_IDLE;
        end

        default: fsm_state <= S_IDLE;
      endcase
    end
  end

endmodule
