// toy_constant_compare.sv
//
// NEGATIIVIKONTROLLI toy_leaky_compare.sv:lle: TAYSI, LEVEA vertailu
// YHDESSA lausekkeessa (sama rakenne kuin ML-KEM:n oma
// `match_out <= (c_in === c_prime)`, jo todettu syklitasolla
// vakioaikaiseksi). Toggle-count-proxy:n TAYTYY nayttaa PIENI/EI
// systemaattista eroa taman moduulin kohdalla (varhaisen ja
// myohaisen/olemattoman eron valilla), TOISIN kuin toy_leaky_
// compare.sv:n kohdalla.

`timescale 1ns/1ps

module toy_constant_compare (
    input  logic clk,
    input  logic reset,
    input  logic start,
    input  logic [255:0] a_in,
    input  logic [255:0] b_in,
    output logic done,
    output logic match_out
);

  typedef enum logic [1:0] {S_IDLE, S_COMPARE, S_DONE} state_e;
  state_e state;

  always_ff @(posedge clk) begin
    if (reset) begin
      state <= S_IDLE;
      done <= 1'b0;
      match_out <= 1'b0;
    end else begin
      done <= 1'b0;
      case (state)
        S_IDLE: if (start) state <= S_COMPARE;

        S_COMPARE: begin
          match_out <= (a_in === b_in);  // TAYSI, LEVEA vertailu - EI varhaista keskeytysta
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
