// pqc_dilithium_verify_core.sv
//
// M5-DILITHIUM-001 DK5: Verify_internal:n oma ydinlaskenta:
// Az_minus_ct1 = NTT^-1(A_hat @ NTT(z) - NTT(t1*2^D) * NTT(c))
// (K=6 polynomia). Sama rakenne kuin pqc_dilithium_keygen_core.sv,
// mutta LISATTYNA "vahenna c*t1_scaled" -termi.
//
// t1_in_flat: t1 Zq-edustajina [0,Q) (JO widenettyna 10-bittisesta
// pakatusta muodosta, kayttopaikan vastuulla).
// c_in: SampleInBall:n tulos, RAAKA etumerkillinen (-1,0,1), 256*8-
// bittisena (SAMA formaatti kuin pqc_dilithium_sample_in_ball.sv:n
// oma coeffs_out_flat).

`timescale 1ns/1ps

module pqc_dilithium_verify_core #(
    parameter int Q = 8380417,
    parameter int CW = 23,
    parameter int K = 6,
    parameter int L = 5,
    parameter int D = 13
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [K*L*256*CW-1:0] A_hat_in,
    input  logic [L*256*CW-1:0] z_in_flat,      // z Zq-edustajina [0,Q) (etumerkkimuunnos jo tehty kayttopaikassa)
    input  logic [K*256*CW-1:0] t1_in_flat,     // t1 Zq-edustajina [0,Q)
    input  logic [256*8-1:0] c_in_flat,          // SampleInBall:n raaka tulos (-1,0,1)

    output logic done,
    output logic [K*256*CW-1:0] az_minus_ct1_out_flat
);

  // --- Sisaiset tallennusrekisterit ---
  logic [256*CW-1:0] A_hat [0:K-1][0:L-1];
  logic [256*CW-1:0] z_hat [0:L-1];
  logic [256*CW-1:0] t1_scaled_hat [0:K-1];
  logic [256*CW-1:0] c_hat;
  logic [256*CW-1:0] az_hat [0:K-1];
  logic [256*CW-1:0] ct1_hat [0:K-1];
  logic [256*CW-1:0] diff_hat [0:K-1];
  logic [256*CW-1:0] result_raw [0:K-1];

  genvar gi, gj;
  generate
    for (gi = 0; gi < K; gi++) begin : g_a_row
      for (gj = 0; gj < L; gj++) begin : g_a_col
        assign A_hat[gi][gj] = A_hat_in[(gi*L+gj)*256*CW +: 256*CW];
      end
    end
  endgenerate

  // --- z:n etumerkillinen->Zq-muunnos EI tarvita (jo Zq-edustajina
  // portissa) - c:n oma muunnos raa'asta (-1,0,1) Zq:ksi TARVITAAN ---
  logic [256*CW-1:0] c_zq;
  generate
    for (gi = 0; gi < 256; gi++) begin : g_c_conv
      wire signed [7:0] raw = c_in_flat[gi*8 +: 8];
      assign c_zq[gi*CW +: CW] = (raw < 0) ? (Q + raw) : raw;
    end
  endgenerate

  // --- t1*2^D mod Q (taysin kombinatorinen, kaikki K*256 kerrointa) ---
  logic [256*CW-1:0] t1_scaled [0:K-1];
  generate
    for (gi = 0; gi < K; gi++) begin : g_t1scale_row
      for (gj = 0; gj < 256; gj++) begin : g_t1scale_coeff
        wire [CW+D-1:0] wide = {t1_in_flat[(gi*256+gj)*CW +: CW], {D{1'b0}}};  // *2^D
        assign t1_scaled[gi][gj*CW +: CW] = wide % Q;
      end
    end
  endgenerate

  // --- Jaettu forward-NTT-ydin (z:lle, t1_scaled:lle, c:lle) ---
  logic fwd_start, fwd_done;
  logic [256*CW-1:0] fwd_in, fwd_out;
  pqc_dilithium_ntt_core #(.Q(Q), .CW(CW)) fwd_dut (
    .clk(clk), .reset(reset), .start(fwd_start),
    .coeffs_in(fwd_in), .done(fwd_done), .coeffs_out(fwd_out)
  );

  // --- Jaettu inverse-NTT-ydin ---
  logic inv_start, inv_done;
  logic [256*CW-1:0] inv_in, inv_out;
  pqc_dilithium_ntt_inverse_core #(.Q(Q), .CW(CW)) inv_dut (
    .clk(clk), .reset(reset), .start(inv_start),
    .coeffs_in(inv_in), .done(inv_done), .coeffs_out(inv_out)
  );

  // --- Barrett-kertolasku ---
  logic [CW-1:0] mm_a_in, mm_b_in, mm_out;
  pqc_dilithium_barrett_mulmod #(.Q(Q)) mm_dut (
    .a_in(mm_a_in), .b_in(mm_b_in), .result_out(mm_out)
  );

  typedef enum logic [4:0] {
    S_IDLE,
    S_FWD_Z_START, S_FWD_Z_WAIT, S_FWD_Z_STORE,
    S_FWD_T1_START, S_FWD_T1_WAIT, S_FWD_T1_STORE,
    S_FWD_C_START, S_FWD_C_WAIT, S_FWD_C_STORE,
    S_AZ_ROW_INIT, S_AZ_ACC_SETUP, S_AZ_ACC_CAPTURE, S_AZ_ACC_NEXT,
    S_CT1_SETUP, S_CT1_CAPTURE, S_CT1_NEXT,
    S_SUB,
    S_INV_START, S_INV_WAIT, S_INV_STORE,
    S_DONE
  } state_e;
  state_e state;

  logic [3:0] z_ctr, t1_ctr, row_ctr, col_ctr;
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
          z_ctr <= 4'd0;
          state <= S_FWD_Z_START;
        end

        // --- Forward NTT z[0..L-1] ---
        S_FWD_Z_START: begin
          fwd_in <= z_in_flat[z_ctr*256*CW +: 256*CW];
          fwd_start <= 1'b1;
          state <= S_FWD_Z_WAIT;
        end
        S_FWD_Z_WAIT: if (fwd_done) state <= S_FWD_Z_STORE;
        S_FWD_Z_STORE: begin
          z_hat[z_ctr] <= fwd_out;
          if (z_ctr == L-1) begin
            t1_ctr <= 4'd0;
            state <= S_FWD_T1_START;
          end else begin
            z_ctr <= z_ctr + 4'd1;
            state <= S_FWD_Z_START;
          end
        end

        // --- Forward NTT t1_scaled[0..K-1] ---
        S_FWD_T1_START: begin
          fwd_in <= t1_scaled[t1_ctr];
          fwd_start <= 1'b1;
          state <= S_FWD_T1_WAIT;
        end
        S_FWD_T1_WAIT: if (fwd_done) state <= S_FWD_T1_STORE;
        S_FWD_T1_STORE: begin
          t1_scaled_hat[t1_ctr] <= fwd_out;
          if (t1_ctr == K-1) begin
            state <= S_FWD_C_START;
          end else begin
            t1_ctr <= t1_ctr + 4'd1;
            state <= S_FWD_T1_START;
          end
        end

        // --- Forward NTT c ---
        S_FWD_C_START: begin
          fwd_in <= c_zq;
          fwd_start <= 1'b1;
          state <= S_FWD_C_WAIT;
        end
        S_FWD_C_WAIT: if (fwd_done) state <= S_FWD_C_STORE;
        S_FWD_C_STORE: begin
          c_hat <= fwd_out;
          row_ctr <= 4'd0;
          state <= S_AZ_ROW_INIT;
        end

        // --- Az_hat[row] = sum_j(A[row][j]*z_hat[j]) ---
        S_AZ_ROW_INIT: begin
          col_ctr <= 4'd0;
          coeff_ctr <= 9'd0;
          acc_reg <= '0;
          state <= S_AZ_ACC_SETUP;
        end

        S_AZ_ACC_SETUP: begin
          mm_a_in <= A_hat[row_ctr][col_ctr][coeff_ctr*CW +: CW];
          mm_b_in <= z_hat[col_ctr][coeff_ctr*CW +: CW];
          state <= S_AZ_ACC_CAPTURE;
        end

        S_AZ_ACC_CAPTURE: begin
          begin
            logic [CW:0] sum_wide;
            sum_wide = {1'b0, acc_reg} + {1'b0, mm_out};
            acc_reg <= (sum_wide >= Q) ? (sum_wide - Q) : sum_wide[CW-1:0];
          end
          state <= S_AZ_ACC_NEXT;
        end

        S_AZ_ACC_NEXT: begin
          if (col_ctr == L-1) begin
            az_hat[row_ctr][coeff_ctr*CW +: CW] <= acc_reg;
            col_ctr <= 4'd0;
            acc_reg <= '0;
            if (coeff_ctr == 9'd255) begin
              if (row_ctr == K-1) begin
                row_ctr <= 4'd0;
                coeff_ctr <= 9'd0;
                state <= S_CT1_SETUP;
              end else begin
                row_ctr <= row_ctr + 4'd1;
                coeff_ctr <= 9'd0;
                state <= S_AZ_ACC_SETUP;
              end
            end else begin
              coeff_ctr <= coeff_ctr + 9'd1;
              state <= S_AZ_ACC_SETUP;
            end
          end else begin
            col_ctr <= col_ctr + 4'd1;
            state <= S_AZ_ACC_SETUP;
          end
        end

        // --- ct1_hat[row] = t1_scaled_hat[row] * c_hat (pisteittain) ---
        S_CT1_SETUP: begin
          mm_a_in <= t1_scaled_hat[row_ctr][coeff_ctr*CW +: CW];
          mm_b_in <= c_hat[coeff_ctr*CW +: CW];
          state <= S_CT1_CAPTURE;
        end

        S_CT1_CAPTURE: begin
          ct1_hat[row_ctr][coeff_ctr*CW +: CW] <= mm_out;
          state <= S_CT1_NEXT;
        end

        S_CT1_NEXT: begin
          if (coeff_ctr == 9'd255) begin
            if (row_ctr == K-1) begin
              row_ctr <= 4'd0;
              state <= S_SUB;
            end else begin
              row_ctr <= row_ctr + 4'd1;
              coeff_ctr <= 9'd0;
              state <= S_CT1_SETUP;
            end
          end else begin
            coeff_ctr <= coeff_ctr + 9'd1;
            state <= S_CT1_SETUP;
          end
        end

        // --- diff_hat = az_hat - ct1_hat (taysin kombinatorinen) ---
        S_SUB: begin
          row_ctr <= 4'd0;
          state <= S_INV_START;
        end

        // --- Inverse NTT diff_hat[0..K-1] -> result_raw ---
        S_INV_START: begin
          inv_in <= diff_hat[row_ctr];
          inv_start <= 1'b1;
          state <= S_INV_WAIT;
        end
        S_INV_WAIT: if (inv_done) state <= S_INV_STORE;
        S_INV_STORE: begin
          result_raw[row_ctr] <= inv_out;
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

  // --- diff_hat = az_hat - ct1_hat mod Q (taysin kombinatorinen) ---
  generate
    for (gi = 0; gi < K; gi++) begin : g_sub_row
      for (gj = 0; gj < 256; gj++) begin : g_sub_coeff
        wire signed [CW:0] a_s = $signed({1'b0, az_hat[gi][gj*CW +: CW]});
        wire signed [CW:0] b_s = $signed({1'b0, ct1_hat[gi][gj*CW +: CW]});
        wire signed [CW:0] diff_s = a_s - b_s;
        assign diff_hat[gi][gj*CW +: CW] = (diff_s < 0) ? (diff_s + Q) : diff_s[CW-1:0];
      end
    end
  endgenerate

  generate
    for (gi = 0; gi < K; gi++) begin : g_out
      assign az_minus_ct1_out_flat[gi*256*CW +: 256*CW] = result_raw[gi];
    end
  endgenerate

endmodule
