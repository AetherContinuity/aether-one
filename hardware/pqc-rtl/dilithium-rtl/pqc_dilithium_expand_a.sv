// pqc_dilithium_expand_a.sv
//
// M5-DILITHIUM-001 DK2: koko A-matriisin (K=6 x L=5 = 30 polynomia)
// generointi. Silmukoi jo todistetun pqc_dilithium_rej_ntt_poly.sv:n
// 30 kertaa, tallentaen tulokset paketoituun ulostuloon.
//
// A_out_flat-jarjestys: A[i][j] loytyy indeksista (i*L+j)*256*CW,
// matching dilithium-py:n oman A_data[i][j]-indeksoinnin (i=rivi
// 0..K-1, j=sarake 0..L-1).

`timescale 1ns/1ps

module pqc_dilithium_expand_a #(
    parameter int Q = 8380417,
    parameter int CW = 23,
    parameter int K = 6,
    parameter int L = 5
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [255:0] rho_in,

    output logic done,
    output logic [K*L*256*CW-1:0] A_out_flat
);

  logic poly_start, poly_done, poly_error_exhausted;
  logic [7:0] i_reg, j_reg;
  logic [256*CW-1:0] poly_out;

  pqc_dilithium_rej_ntt_poly #(.Q(Q), .CW(CW)) poly_dut (
    .clk(clk), .reset(reset), .start(poly_start),
    .rho_in(rho_in), .i_in(i_reg), .j_in(j_reg),
    .done(poly_done), .error_exhausted(poly_error_exhausted), .coeffs_out(poly_out)
  );

  // Sisainen, ei-porttina-oleva unpacked-taulukko (turvallinen Icarus
  // Verilogissa - vain PORTIT eivat saa olla unpacked-taulukoita)
  logic [256*CW-1:0] A_mem [0:K-1][0:L-1];

  typedef enum logic [2:0] { S_IDLE, S_START_POLY, S_WAIT_POLY, S_STORE, S_NEXT, S_DONE } state_e;
  state_e state;

  logic [3:0] i_ctr;
  logic [3:0] j_ctr;

  always_ff @(posedge clk) begin
    poly_start <= 1'b0;
    done <= 1'b0;

    if (reset) begin
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: if (start) begin
          i_ctr <= 4'd0;
          j_ctr <= 4'd0;
          state <= S_START_POLY;
        end

        S_START_POLY: begin
          i_reg <= {4'b0, i_ctr};
          j_reg <= {4'b0, j_ctr};
          poly_start <= 1'b1;
          state <= S_WAIT_POLY;
        end

        S_WAIT_POLY: if (poly_done) begin
          state <= S_STORE;
        end

        S_STORE: begin
          A_mem[i_ctr][j_ctr] <= poly_out;
          state <= S_NEXT;
        end

        S_NEXT: begin
          if (j_ctr == L-1) begin
            j_ctr <= 4'd0;
            if (i_ctr == K-1) begin
              state <= S_DONE;
            end else begin
              i_ctr <= i_ctr + 4'd1;
              state <= S_START_POLY;
            end
          end else begin
            j_ctr <= j_ctr + 4'd1;
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

  genvar gi, gj;
  generate
    for (gi = 0; gi < K; gi++) begin : g_row
      for (gj = 0; gj < L; gj++) begin : g_col
        assign A_out_flat[(gi*L+gj)*256*CW +: 256*CW] = A_mem[gi][gj];
      end
    end
  endgenerate

endmodule
