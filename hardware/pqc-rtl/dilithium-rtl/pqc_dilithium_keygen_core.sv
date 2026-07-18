// pqc_dilithium_keygen_core.sv
//
// M5-DILITHIUM-001 DK4: KeyGenin ydinlaskenta: t = NTT^-1(A_hat @
// NTT(s1)) + s2 (K=6 polynomia). Kayttaa jo todistettuja NTT-ytimia
// (forward+inverse) seka Barrett-kertolaskureduktiota. A_hat ja s1/s2
// SYOTETAAN valmiiksi laskettuina (DK2/DK3:n tuotoksina) - tama
// moduuli VAIN yhdistaa ne, EI sisalla omaa nayttestysta.
//
// A_hat:n oma edustus: JO NTT-domainissa (dilithium-py:n
// rejection_sample_ntt_poly palauttaa is_ntt=True-polynomin suoraan) -
// EI tarvitse erillista NTT-muunnosta A:lle, VAIN s1:lle.

`timescale 1ns/1ps

module pqc_dilithium_keygen_core #(
    parameter int Q = 8380417,
    parameter int CW = 23,
    parameter int K = 6,
    parameter int L = 5
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [K*L*256*CW-1:0] A_hat_in,   // NTT-domainissa jo (ExpandA:n tuotos)
    input  logic [L*256*8-1:0] s1_in_flat,     // raaka etumerkillinen (-4..4, ExpandS:n tuotos)
    input  logic [K*256*8-1:0] s2_in_flat,     // raaka etumerkillinen (-4..4, ExpandS:n tuotos)

    output logic done,
    output logic [K*256*CW-1:0] t_out_flat      // t = NTT^-1(A*NTT(s1)) + s2, Zq-edustajina [0,Q)
);

  // --- Sisaiset (ei-porttina) tallennusrekisterit ---
  logic [256*CW-1:0] A_hat [0:K-1][0:L-1];
  logic [256*CW-1:0] s1_hat [0:L-1];   // NTT(s1), Zq-edustajina
  logic [256*CW-1:0] t_hat [0:K-1];    // A_hat @ s1_hat (NTT-domainissa)
  logic [256*CW-1:0] t_raw [0:K-1];    // NTT^-1(t_hat)
  logic [256*CW-1:0] t_final [0:K-1];  // t_raw + s2

  genvar gi, gj;
  generate
    for (gi = 0; gi < K; gi++) begin : g_a_row
      for (gj = 0; gj < L; gj++) begin : g_a_col
        assign A_hat[gi][gj] = A_hat_in[(gi*L+gj)*256*CW +: 256*CW];
      end
    end
  endgenerate

  // --- s1:n muunnos raa'asta etumerkillisesta Zq-edustajaksi
  // (jaettu forward-NTT-ytimen syotetta varten) ---
  logic [256*CW-1:0] s1_zq [0:L-1];
  generate
    for (gi = 0; gi < L; gi++) begin : g_s1_conv
      for (gj = 0; gj < 256; gj++) begin : g_s1_coeff
        // Etumerkillinen -4..4 -> Zq [0,Q): jos negatiivinen, lisaa Q
        wire signed [7:0] raw = s1_in_flat[(gi*256+gj)*8 +: 8];
        assign s1_zq[gi][gj*CW +: CW] = (raw < 0) ? (Q + raw) : raw;
      end
    end
  endgenerate

  logic [256*CW-1:0] s2_zq [0:K-1];
  generate
    for (gi = 0; gi < K; gi++) begin : g_s2_conv
      for (gj = 0; gj < 256; gj++) begin : g_s2_coeff
        wire signed [7:0] raw = s2_in_flat[(gi*256+gj)*8 +: 8];
        assign s2_zq[gi][gj*CW +: CW] = (raw < 0) ? (Q + raw) : raw;
      end
    end
  endgenerate

  // --- Jaettu forward-NTT-ydin (s1:lle) ---
  logic fwd_start, fwd_done;
  logic [256*CW-1:0] fwd_in, fwd_out;
  pqc_dilithium_ntt_core #(.Q(Q), .CW(CW)) fwd_dut (
    .clk(clk), .reset(reset), .start(fwd_start),
    .coeffs_in(fwd_in), .done(fwd_done), .coeffs_out(fwd_out)
  );

  // --- Jaettu inverse-NTT-ydin (t_hat:lle) ---
  logic inv_start, inv_done;
  logic [256*CW-1:0] inv_in, inv_out;
  pqc_dilithium_ntt_inverse_core #(.Q(Q), .CW(CW)) inv_dut (
    .clk(clk), .reset(reset), .start(inv_start),
    .coeffs_in(inv_in), .done(inv_done), .coeffs_out(inv_out)
  );

  // --- Barrett-kertolasku pisteittaiselle A*s1_hat-tulolle ---
  logic [CW-1:0] mm_a_in, mm_b_in, mm_out;
  pqc_dilithium_barrett_mulmod #(.Q(Q)) mm_dut (
    .a_in(mm_a_in), .b_in(mm_b_in), .result_out(mm_out)
  );

  typedef enum logic [4:0] {
    S_IDLE,
    S_FWD_START, S_FWD_WAIT, S_FWD_STORE,
    S_MM_ROW_INIT, S_MM_ACC_SETUP, S_MM_ACC_CAPTURE, S_MM_ACC_NEXT,
    S_INV_START, S_INV_WAIT, S_INV_STORE,
    S_ADD, S_DONE
  } state_e;
  state_e state;

  logic [3:0] s1_ctr;   // 0..L-1, forward-NTT-silmukka
  logic [3:0] row_ctr;  // 0..K-1
  logic [3:0] col_ctr;  // 0..L-1 (matriisikertolaskun sisempi silmukka)
  logic [8:0] coeff_ctr; // 0..255

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
          s1_ctr <= 4'd0;
          state <= S_FWD_START;
        end

        // --- Forward NTT jokaiselle s1[i]:lle ---
        S_FWD_START: begin
          fwd_in <= s1_zq[s1_ctr];
          fwd_start <= 1'b1;
          state <= S_FWD_WAIT;
        end

        S_FWD_WAIT: if (fwd_done) state <= S_FWD_STORE;

        S_FWD_STORE: begin
          s1_hat[s1_ctr] <= fwd_out;
          if (s1_ctr == L-1) begin
            row_ctr <= 4'd0;
            state <= S_MM_ROW_INIT;
          end else begin
            s1_ctr <= s1_ctr + 4'd1;
            state <= S_FWD_START;
          end
        end

        // --- Matriisikertolasku: t_hat[row] = sum_j(A[row][j]*s1_hat[j]) ---
        S_MM_ROW_INIT: begin
          col_ctr <= 4'd0;
          coeff_ctr <= 9'd0;
          acc_reg <= '0;
          state <= S_MM_ACC_SETUP;
        end

        S_MM_ACC_SETUP: begin
          mm_a_in <= A_hat[row_ctr][col_ctr][coeff_ctr*CW +: CW];
          mm_b_in <= s1_hat[col_ctr][coeff_ctr*CW +: CW];
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
            // tama kerroin valmis kaikilta L sarakkeilta
            t_hat[row_ctr][coeff_ctr*CW +: CW] <= acc_reg;
            col_ctr <= 4'd0;
            acc_reg <= '0;
            if (coeff_ctr == 9'd255) begin
              // koko rivi valmis
              if (row_ctr == K-1) begin
                row_ctr <= 4'd0;
                state <= S_INV_START;
              end else begin
                row_ctr <= row_ctr + 4'd1;
                coeff_ctr <= 9'd0;
                state <= S_MM_ACC_SETUP;  // col_ctr=0 jo, aloita seuraava rivi
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

        // --- Inverse NTT jokaiselle t_hat[row]:lle ---
        S_INV_START: begin
          inv_in <= t_hat[row_ctr];
          inv_start <= 1'b1;
          state <= S_INV_WAIT;
        end

        S_INV_WAIT: if (inv_done) state <= S_INV_STORE;

        S_INV_STORE: begin
          t_raw[row_ctr] <= inv_out;
          if (row_ctr == K-1) begin
            row_ctr <= 4'd0;
            state <= S_ADD;
          end else begin
            row_ctr <= row_ctr + 4'd1;
            state <= S_INV_START;
          end
        end

        // --- t = t_raw + s2 (kaikki K polynomia, kaikki 256 kerrointa yhdella syklilla combinatorisesti) ---
        S_ADD: begin
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

  // --- t_raw + s2 mod Q, taysin kombinatorinen (kaikki K*256 kerrointa rinnakkain) ---
  generate
    for (gi = 0; gi < K; gi++) begin : g_add_row
      for (gj = 0; gj < 256; gj++) begin : g_add_coeff
        wire [CW:0] sum_w = {1'b0, t_raw[gi][gj*CW +: CW]} + {1'b0, s2_zq[gi][gj*CW +: CW]};
        assign t_final[gi][gj*CW +: CW] = (sum_w >= Q) ? (sum_w - Q) : sum_w[CW-1:0];
      end
    end
  endgenerate

  generate
    for (gi = 0; gi < K; gi++) begin : g_out
      assign t_out_flat[gi*256*CW +: 256*CW] = t_final[gi];
    end
  endgenerate

endmodule
