// pqc_dilithium_expand_mask_vector.sv
//
// M5-DILITHIUM-001 DK6 S2: koko y-vektorin (L=5 polynomia) muodostus.
// Silmukoi todistetun pqc_dilithium_expand_mask_poly.sv:n L kertaa,
// kappa (=mu FIPS 204:n omassa merkinnassa) KIINTEA koko kutsun ajan,
// i vaihtelee 0..L-1.

`timescale 1ns/1ps

module pqc_dilithium_expand_mask_vector #(
    parameter int GAMMA1 = 524288,
    parameter int ZW = 24,
    parameter int L = 5
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [511:0] rho_prime_in,
    input  logic [15:0] kappa_in,   // kappa (mu), pysyy samana koko kutsun ajan

    output logic done,
    output logic [L*256*ZW-1:0] y_out_flat
);

  logic poly_start, poly_done;
  logic [15:0] kappa_plus_i;
  logic [256*ZW-1:0] poly_out;

  pqc_dilithium_expand_mask_poly #(.GAMMA1(GAMMA1), .ZW(ZW)) poly_dut (
    .clk(clk), .reset(reset), .start(poly_start),
    .rho_prime_in(rho_prime_in), .kappa_plus_i_in(kappa_plus_i),
    .done(poly_done), .y_out_flat(poly_out)
  );

  logic [256*ZW-1:0] y_mem [0:L-1];

  typedef enum logic [2:0] { S_IDLE, S_START_POLY, S_WAIT_POLY, S_STORE, S_DONE } state_e;
  state_e state;

  logic [3:0] i_ctr;

  always_ff @(posedge clk) begin
    poly_start <= 1'b0;
    done <= 1'b0;

    if (reset) begin
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: if (start) begin
          i_ctr <= 4'd0;
          state <= S_START_POLY;
        end

        S_START_POLY: begin
          kappa_plus_i <= kappa_in + {12'b0, i_ctr};
          poly_start <= 1'b1;
          state <= S_WAIT_POLY;
        end

        S_WAIT_POLY: if (poly_done) state <= S_STORE;

        S_STORE: begin
          y_mem[i_ctr] <= poly_out;
          if (i_ctr == L-1) begin
            state <= S_DONE;
          end else begin
            i_ctr <= i_ctr + 4'd1;
            state <= S_START_POLY;
          end
        end

        S_DONE: begin
          done <= 1'b1;
          state <= S_IDLE;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

  genvar gi;
  generate
    for (gi = 0; gi < L; gi++) begin : g_out
      assign y_out_flat[gi*256*ZW +: 256*ZW] = y_mem[gi];
    end
  endgenerate

endmodule
