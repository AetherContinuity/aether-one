// pqc_samplentt.sv
//
// M3 Issue #15, Vaihe 2 (loppuunsaattaminen): koko SampleNTT (FIPS 203
// Algoritmi 7), yhdistaen pqc_shake128 (Issue #14, XOF) ja
// pqc_samplentt_reject (tama Issue, hylkaysnaytteenotto). EI uutta
// aritmetiikkaa - vain kokoonpano + FSM.
//
// XOF_BYTES=1008, reilusti yli FIPS 203 Liite B:n 840 tavun
// minimivaatimuksen (280 iteraatiota) - ks. SAMPLENTT_DESIGN_NOTE.md.

`timescale 1ns/1ps

module pqc_samplentt #(
    parameter int XOF_BYTES = 1008,
    parameter int Q         = 3329
)(
    input  logic clk,
    input  logic reset,
    input  logic start,
    input  logic [255:0] rho,      // 32-tavuinen siemen
    input  logic [7:0] byte_j,
    input  logic [7:0] byte_i,
    output logic [16*256-1:0] a_hat,
    output logic [15:0] accepted_count,
    output logic [15:0] rejected_count,
    output logic [15:0] xof_bytes_consumed,
    output logic done,
    output logic error_exhausted
);

  localparam int MAX_BLOCKS = (34 + 167) / 168 + 1;  // 34-tavuinen syote mahtuu yhteen SHAKE128-lohkoon

  typedef enum logic [1:0] {S_IDLE, S_XOF, S_REJECT} state_e;
  state_e fsm_state;

  logic [8*168*MAX_BLOCKS-1:0] shake_msg_in;
  logic shake_start, shake_done;
  logic [8*XOF_BYTES-1:0] xof_data;

  assign shake_msg_in = {{(168*MAX_BLOCKS-34){8'h00}}, byte_i, byte_j, rho};
  // HUOM: pakattu vektori, tavu 0 = rho:n oma tavu 0 (LSB-paassa) -
  // jarjestys: rho (32 tavua, tavu0=LSB) sitten byte_j sitten byte_i,
  // matkien B = rho||j||i -jarjestysta (tavu-indeksi 32=j, 33=i).

  pqc_shake128 #(.MAX_BLOCKS(MAX_BLOCKS), .MAX_OUT_BYTES(XOF_BYTES)) xof_dut (
    .clk(clk), .reset(reset), .start(shake_start),
    .msg_in(shake_msg_in), .msg_len_bytes(16'd34), .out_len_bytes(XOF_BYTES[15:0]),
    .out_data(xof_data), .done(shake_done)
  );

  logic reject_start, reject_done;

  pqc_samplentt_reject #(.XOF_BYTES(XOF_BYTES), .Q(Q)) reject_dut (
    .clk(clk), .reset(reset), .start(reject_start),
    .xof_data(xof_data),
    .a_hat(a_hat), .accepted_count(accepted_count), .rejected_count(rejected_count),
    .xof_bytes_consumed(xof_bytes_consumed), .done(reject_done), .error_exhausted(error_exhausted)
  );

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      fsm_state    <= S_IDLE;
      done         <= 1'b0;
      shake_start  <= 1'b0;
      reject_start <= 1'b0;
    end else begin
      shake_start  <= 1'b0;
      reject_start <= 1'b0;
      case (fsm_state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            shake_start <= 1'b1;
            fsm_state   <= S_XOF;
          end
        end

        S_XOF: begin
          if (shake_done) begin
            reject_start <= 1'b1;
            fsm_state    <= S_REJECT;
          end
        end

        S_REJECT: begin
          if (reject_done) begin
            done      <= 1'b1;
            fsm_state <= S_IDLE;
          end
        end

        default: fsm_state <= S_IDLE;
      endcase
    end
  end

endmodule
