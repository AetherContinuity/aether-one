// pqc_dilithium_sign_w_core.sv
//
// M5-DILITHIUM-001 DK6 S3: w = NTT^-1(A_hat @ NTT(y)) (K=6
// polynomia). Sama rakenne kuin pqc_dilithium_keygen_core.sv:n oma
// t-laskenta, mutta EI vahennystermia (yksinkertaisempi - vain
// forward-NTT(y) + matriisikertolasku + inverse-NTT, ei s2-lisaysta
// eika c*t1-vahennysta).

`timescale 1ns/1ps

module pqc_dilithium_sign_w_core #(
    parameter int Q = 8380417,
    parameter int CW = 23,
    parameter int K = 6,
    parameter int L = 5
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [K*L*256*CW-1:0] A_hat_in,
    input  logic [L*256*CW-1:0] y_in_flat,   // y Zq-edustajina [0,Q)

    output logic done,
    output logic [K*256*CW-1:0] w_out_flat
);

  logic [256*CW-1:0] A_hat [0:K-1][0:L-1];
  logic [256*CW-1:0] y_hat [0:L-1];
  logic [256*CW-1:0] w_hat [0:K-1];
  logic [256*CW-1:0] w_raw [0:K-1];

  genvar gi, gj;
  generate
    for (gi = 0; gi < K; gi++) begin : g_a_row
      for (gj = 0; gj < L; gj++) begin : g_a_col
        assign A_hat[gi][gj] = A_hat_in[(gi*L+gj)*256*CW +: 256*CW];
      end
    end
  endgenerate

  logic fwd_start, fwd_done;
  logic [256*CW-1:0] fwd_in, fwd_out;
  pqc_dilithium_ntt_core #(.Q(Q), .CW(CW)) fwd_dut (
    .clk(clk), .reset(reset), .start(fwd_start),
    .coeffs_in(fwd_in), .done(fwd_done), .coeffs_out(fwd_out)
  );

  logic inv_start, inv_done;
  logic [256*CW-1:0] inv_in, inv_out;
  pqc_dilithium_ntt_inverse_core #(.Q(Q), .CW(CW)) inv_dut (
    .clk(clk), .reset(reset), .start(inv_start),
    .coeffs_in(inv_in), .done(inv_done), .coeffs_out(inv_out)
  );

  logic [CW-1:0] mm_a_in, mm_b_in, mm_out;
  pqc_dilithium_barrett_mulmod #(.Q(Q)) mm_dut (
    .a_in(mm_a_in), .b_in(mm_b_in), .result_out(mm_out)
  );

  typedef enum logic [3:0] {
    S_IDLE,
    S_FWD_Y_START, S_FWD_Y_WAIT, S_FWD_Y_STORE,
    S_MM_ROW_INIT, S_MM_ACC_SETUP, S_MM_ACC_CAPTURE, S_MM_ACC_NEXT,
    S_INV_START, S_INV_WAIT, S_INV_STORE,
    S_DONE
  } state_e;
  state_e state;

  logic [3:0] y_ctr, row_ctr, col_ctr;
  logic [8:0] coeff_ctr;
  logic [CW-1:0] acc_reg;

  always_ff @(posedge clk) begin
    fwd_start <= 1'b0;
    inv_start <= 1'b0;
    done <= 1'b0;

    if (reset) begin
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: if (start) begin
          y_ctr <= 4'd0;
          state <= S_FWD_Y_START;
        end

        S_FWD_Y_START: begin
          fwd_in <= y_in_flat[y_ctr*256*CW +: 256*CW];
          fwd_start <= 1'b1;
          state <= S_FWD_Y_WAIT;
        end
        S_FWD_Y_WAIT: if (fwd_done) state <= S_FWD_Y_STORE;
        S_FWD_Y_STORE: begin
          y_hat[y_ctr] <= fwd_out;
          if (y_ctr == L-1) begin
            row_ctr <= 4'd0;
            state <= S_MM_ROW_INIT;
          end else begin
            y_ctr <= y_ctr + 4'd1;
            state <= S_FWD_Y_START;
          end
        end

        S_MM_ROW_INIT: begin
          col_ctr <= 4'd0;
          coeff_ctr <= 9'd0;
          acc_reg <= '0;
          state <= S_MM_ACC_SETUP;
        end

        S_MM_ACC_SETUP: begin
          mm_a_in <= A_hat[row_ctr][col_ctr][coeff_ctr*CW +: CW];
          mm_b_in <= y_hat[col_ctr][coeff_ctr*CW +: CW];
          state <= S_MM_ACC_CAPTURE;
        end

        S_MM_ACC_CAPTURE: begin
          begin
            logic [CW:0] sum_wide;
            sum_wide = {1'b0, acc_reg} + {1'b0, mm_out};
            acc_reg <= (sum_wide >= Q) ? (sum_wide - Q) : sum_wide[CW-1:0];
          end
          state <= S_MM_ACC_NEXT;
        end

        S_MM_ACC_NEXT: begin
          if (col_ctr == L-1) begin
            w_hat[row_ctr][coeff_ctr*CW +: CW] <= acc_reg;
            col_ctr <= 4'd0;
            acc_reg <= '0;
            if (coeff_ctr == 9'd255) begin
              if (row_ctr == K-1) begin
                row_ctr <= 4'd0;
                state <= S_INV_START;
              end else begin
                row_ctr <= row_ctr + 4'd1;
                coeff_ctr <= 9'd0;
                state <= S_MM_ACC_SETUP;
              end
            end else begin
              coeff_ctr <= coeff_ctr + 9'd1;
              state <= S_MM_ACC_SETUP;
            end
          end else begin
            col_ctr <= col_ctr + 4'd1;
            state <= S_MM_ACC_SETUP;
          end
        end

        S_INV_START: begin
          inv_in <= w_hat[row_ctr];
          inv_start <= 1'b1;
          state <= S_INV_WAIT;
        end
        S_INV_WAIT: if (inv_done) state <= S_INV_STORE;
        S_INV_STORE: begin
          w_raw[row_ctr] <= inv_out;
          if (row_ctr == K-1) begin
            state <= S_DONE;
          end else begin
            row_ctr <= row_ctr + 4'd1;
            state <= S_INV_START;
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

  generate
    for (gi = 0; gi < K; gi++) begin : g_out
      assign w_out_flat[gi*256*CW +: 256*CW] = w_raw[gi];
    end
  endgenerate

endmodule
