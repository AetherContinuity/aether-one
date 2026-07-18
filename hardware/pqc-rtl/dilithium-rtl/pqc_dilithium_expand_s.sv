// pqc_dilithium_expand_s.sv
//
// M5-DILITHIUM-001 DK3: koko s1 (L=5 polynomia) ja s2 (K=6 polynomia)
// -vektoreiden generointi. Silmukoi jo todistetun
// pqc_dilithium_rej_bounded_poly.sv:n 11 kertaa (i=0..L+K-1), sama
// rho_prime kaikille - dilithium-py:n oman _expand_vector_from_seed()
// -indeksoinnin mukaisesti: s1 kayttaa i=0..L-1, s2 kayttaa
// i=L..L+K-1.

`timescale 1ns/1ps

module pqc_dilithium_expand_s #(
    parameter int ETA = 4,
    parameter int K = 6,
    parameter int L = 5
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [511:0] rho_prime_in,

    output logic done,
    output logic [L*256*8-1:0] s1_out_flat,
    output logic [K*256*8-1:0] s2_out_flat
);

  logic poly_start, poly_done, poly_error_exhausted;
  logic [15:0] i_reg;
  logic [256*8-1:0] poly_out;

  pqc_dilithium_rej_bounded_poly #(.ETA(ETA)) poly_dut (
    .clk(clk), .reset(reset), .start(poly_start),
    .rho_prime_in(rho_prime_in), .i_in(i_reg),
    .done(poly_done), .error_exhausted(poly_error_exhausted), .coeffs_out_flat(poly_out)
  );

  logic [256*8-1:0] s1_mem [0:L-1];
  logic [256*8-1:0] s2_mem [0:K-1];

  typedef enum logic [2:0] { S_IDLE, S_START_POLY, S_WAIT_POLY, S_STORE, S_NEXT, S_DONE } state_e;
  state_e state;

  logic [3:0] i_ctr;  // 0..L+K-1 (0..10)

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
          i_reg <= {12'b0, i_ctr};
          poly_start <= 1'b1;
          state <= S_WAIT_POLY;
        end

        S_WAIT_POLY: if (poly_done) state <= S_STORE;

        S_STORE: begin
          if (i_ctr < L) s1_mem[i_ctr] <= poly_out;
          else s2_mem[i_ctr - L[3:0]] <= poly_out;
          state <= S_NEXT;
        end

        S_NEXT: begin
          if (i_ctr == L+K-1) begin
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
    for (gi = 0; gi < L; gi++) begin : g_s1
      assign s1_out_flat[gi*256*8 +: 256*8] = s1_mem[gi];
    end
    for (gi = 0; gi < K; gi++) begin : g_s2
      assign s2_out_flat[gi*256*8 +: 256*8] = s2_mem[gi];
    end
  endgenerate

endmodule
