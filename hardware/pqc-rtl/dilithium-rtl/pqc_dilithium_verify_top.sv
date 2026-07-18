// pqc_dilithium_verify_top.sv
//
// M5-DILITHIUM-001: KOKO ML-DSA-65.Verify_internal (FIPS 204
// Algoritmi 8). Yhdistaa KAIKKI DK5:n uudet rakennuspalikat
// (SampleInBall, Decompose/UseHint, unpack_z, unpack_h, pack_w) ja
// KeyGenista uudelleenkaytetyt osat (ExpandA, NTT-forward/inverse,
// SHAKE256).
//
// TAMA ENSIMMAINEN VERSIO: viestin (m) pituus KIINTEA 32 tavuun
// yksinkertaisuuden vuoksi - laajennettavissa myohemmin muuttuvan
// pituiseksi jos/kun tarvitaan.
//
// EI VIELA validointeja (h.sum_hint()<=OMEGA, z.check_norm_bound) -
// TAMA ENSIMMAINEN VERSIO todentaa VAIN "aidon polun" (kelvollinen
// allekirjoitus, ei validointivirheita) - validointihaarat voidaan
// lisata myohemmin tarvittaessa.

`timescale 1ns/1ps

module pqc_dilithium_verify_top #(
    parameter int Q = 8380417,
    parameter int CW = 23,
    parameter int K = 6,
    parameter int L = 5,
    parameter int TAU = 49,
    parameter int D = 13,
    parameter int MSG_BYTES = 32
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [8*(32+K*320)-1:0] pk_in,               // 1952 tavua
    input  logic [8*(48+L*640+55+K)-1:0] sig_in,          // 3309 tavua (c_tilde+z+h)
    input  logic [8*MSG_BYTES-1:0] m_in,

    output logic done,
    output logic verify_ok
);

  localparam int SIG_BYTES = 48+L*640+55+K;  // 3309

  // --- Vaihe 1: pk:n purku (triviaali viipalointi) ---
  wire [255:0] rho = pk_in[255:0];
  wire [K*256*10-1:0] t1_packed = pk_in[8*(32+K*320)-1:256];

  // --- Vaihe 2: sig:n purku ---
  wire [383:0] c_tilde = sig_in[383:0];
  wire [L*256*20-1:0] z_packed = sig_in[383+L*640*8:384];
  wire [8*(55+K)-1:0] h_bytes = sig_in[8*SIG_BYTES-1:384+L*640*8];

  logic [L*256*24-1:0] z_flat;
  pqc_dilithium_unpack_z_vector #(.ZW(24), .L(L)) unpack_z_dut (
    .packed_in(z_packed), .z_out_flat(z_flat)
  );

  logic unpack_h_start, unpack_h_done;
  logic [K*256-1:0] h_flat;
  pqc_dilithium_unpack_h #(.OMEGA(55), .K(K)) unpack_h_dut (
    .clk(clk), .reset(reset), .start(unpack_h_start),
    .h_bytes_in(h_bytes), .done(unpack_h_done), .h_out_flat(h_flat)
  );

  // --- Vaihe 3: A_hat = ExpandA(rho) ---
  logic expA_start, expA_done;
  logic [K*L*256*CW-1:0] A_hat;
  pqc_dilithium_expand_a #(.Q(Q), .CW(CW), .K(K), .L(L)) expA_dut (
    .clk(clk), .reset(reset), .start(expA_start),
    .rho_in(rho), .done(expA_done), .A_out_flat(A_hat)
  );

  // --- Vaihe 4: tr=H(pk,64), mu=H(tr||m,64) ---
  logic tr_shake_start, tr_shake_done;
  logic [8*136*15-1:0] tr_shake_msg_in;
  logic [8*64-1:0] tr_shake_out;
  pqc_shake256 #(.MAX_BLOCKS(15), .MAX_OUT_BYTES(64)) tr_shake_dut (
    .clk(clk), .reset(reset), .start(tr_shake_start),
    .msg_in(tr_shake_msg_in), .msg_len_bytes(16'(32+K*320)), .out_len_bytes(16'd64),
    .out_data(tr_shake_out), .done(tr_shake_done)
  );

  logic mu_shake_start, mu_shake_done;
  logic [8*136-1:0] mu_shake_msg_in;
  logic [8*64-1:0] mu_shake_out;
  pqc_shake256 #(.MAX_BLOCKS(1), .MAX_OUT_BYTES(64)) mu_shake_dut (
    .clk(clk), .reset(reset), .start(mu_shake_start),
    .msg_in(mu_shake_msg_in), .msg_len_bytes(16'(64+MSG_BYTES)), .out_len_bytes(16'd64),
    .out_data(mu_shake_out), .done(mu_shake_done)
  );

  logic [511:0] tr_reg, mu_reg;

  // --- Vaihe 5: c=SampleInBall(c_tilde) ---
  logic sib_start, sib_done, sib_error;
  logic [256*8-1:0] c_raw;
  pqc_dilithium_sample_in_ball #(.TAU(TAU)) sib_dut (
    .clk(clk), .reset(reset), .start(sib_start),
    .c_tilde_in(c_tilde), .done(sib_done), .error_exhausted(sib_error),
    .coeffs_out_flat(c_raw)
  );

  // c_raw (etumerkillinen -1,0,1) -> Zq-edustaja
  logic [256*CW-1:0] c_zq;
  genvar gci;
  generate
    for (gci = 0; gci < 256; gci++) begin : g_c_conv
      wire signed [7:0] raw = c_raw[gci*8 +: 8];
      assign c_zq[gci*CW +: CW] = (raw < 0) ? (Q + raw) : raw;
    end
  endgenerate

  // --- Jaettu forward-NTT-ydin (c, z[0..L-1], t1_scaled[0..K-1]) ---
  logic fwd_start, fwd_done;
  logic [256*CW-1:0] fwd_in, fwd_out;
  pqc_dilithium_ntt_core #(.Q(Q), .CW(CW)) fwd_dut (
    .clk(clk), .reset(reset), .start(fwd_start),
    .coeffs_in(fwd_in), .done(fwd_done), .coeffs_out(fwd_out)
  );

  logic [256*CW-1:0] c_hat;
  logic [256*CW-1:0] z_hat [0:L-1];
  logic [256*CW-1:0] t1_hat [0:K-1];

  // z (etumerkillinen 24-bit) -> Zq-edustaja
  logic [256*CW-1:0] z_zq [0:L-1];
  genvar gzi, gzj;
  generate
    for (gzi = 0; gzi < L; gzi++) begin : g_z_row
      for (gzj = 0; gzj < 256; gzj++) begin : g_z_coeff
        wire signed [23:0] raw = z_flat[(gzi*256+gzj)*24 +: 24];
        wire signed [23:0] raw_mod = raw % $signed({1'b0,24'(Q)});
        assign z_zq[gzi][gzj*CW +: CW] = (raw_mod < 0) ? (24'(Q) + raw_mod) : raw_mod;
      end
    end
  endgenerate

  // t1 (10-bit tiukka pakkaus) -> skaalattu (t1*2^D) Zq-edustaja
  logic [256*CW-1:0] t1_scaled [0:K-1];
  genvar gti, gtj;
  generate
    for (gti = 0; gti < K; gti++) begin : g_t1_row
      for (gtj = 0; gtj < 256; gtj++) begin : g_t1_coeff
        wire [9:0] t1_val = t1_packed[(gti*256+gtj)*10 +: 10];
        assign t1_scaled[gti][gtj*CW +: CW] = {t1_val, {D{1'b0}}};  // t1 << D
      end
    end
  endgenerate

  // --- Barrett-kertolasku matriisikertolaskuun ---
  logic [CW-1:0] mm_a_in, mm_b_in, mm_out;
  pqc_dilithium_barrett_mulmod #(.Q(Q)) mm_dut (
    .a_in(mm_a_in), .b_in(mm_b_in), .result_out(mm_out)
  );

  // --- Jaettu inverse-NTT-ydin (Az_hat[0..K-1]) ---
  logic inv_start, inv_done;
  logic [256*CW-1:0] inv_in, inv_out;
  pqc_dilithium_ntt_inverse_core #(.Q(Q), .CW(CW)) inv_dut (
    .clk(clk), .reset(reset), .start(inv_start),
    .coeffs_in(inv_in), .done(inv_done), .coeffs_out(inv_out)
  );

  logic [256*CW-1:0] Az_hat [0:K-1];
  logic [256*CW-1:0] Az_minus_ct1 [0:K-1];

  // --- UseHint koko w'-vektorille (taysin kombinatorinen) ---
  logic [K*256*4-1:0] w_prime_flat;
  genvar gwi, gwj;
  generate
    for (gwi = 0; gwi < K; gwi++) begin : g_w_row
      for (gwj = 0; gwj < 256; gwj++) begin : g_w_coeff
        wire [3:0] uh_out;
        pqc_dilithium_use_hint #(.Q(Q), .CW(CW)) uh_dut (
          .h_in(h_flat[gwi*256+gwj]),
          .r_in(Az_minus_ct1[gwi][gwj*CW +: CW]),
          .result_out(uh_out)
        );
        assign w_prime_flat[(gwi*256+gwj)*4 +: 4] = uh_out;
      end
    end
  endgenerate

  logic [8*K*128-1:0] w_prime_bytes;
  pqc_dilithium_pack_w #(.K(K)) pack_w_dut (
    .w_prime_in_flat(w_prime_flat), .w_prime_packed_out(w_prime_bytes)
  );

  // --- Lopullinen SHAKE256(mu||w_prime_bytes,48) ---
  logic final_shake_start, final_shake_done;
  logic [8*136*6-1:0] final_shake_msg_in;
  logic [8*48-1:0] final_shake_out;
  pqc_shake256 #(.MAX_BLOCKS(6), .MAX_OUT_BYTES(48)) final_shake_dut (
    .clk(clk), .reset(reset), .start(final_shake_start),
    .msg_in(final_shake_msg_in), .msg_len_bytes(16'(64+K*128)), .out_len_bytes(16'd48),
    .out_data(final_shake_out), .done(final_shake_done)
  );

  typedef enum logic [5:0] {
    S_IDLE,
    S_START_TR, S_WAIT_TR,
    S_START_MU, S_WAIT_MU,
    S_START_PARALLEL_A, S_WAIT_A,
    S_START_SIB, S_WAIT_SIB,
    S_START_UNPACK_H, S_WAIT_UNPACK_H,
    S_FWD_C_START, S_FWD_C_WAIT,
    S_FWD_Z_START, S_FWD_Z_WAIT, S_FWD_Z_STORE,
    S_FWD_T1_START, S_FWD_T1_WAIT, S_FWD_T1_STORE,
    S_MM_ROW_INIT, S_MM_ACC_SETUP, S_MM_ACC_CAPTURE, S_MM_ACC_NEXT,
    S_MM_SUB_SETUP, S_MM_SUB_CAPTURE,
    S_INV_START, S_INV_WAIT, S_INV_STORE,
    S_FINAL_SHAKE_START, S_FINAL_SHAKE_WAIT,
    S_COMPARE, S_DONE
  } state_e;
  state_e state;

  logic [3:0] z_ctr, t1_ctr;
  logic [3:0] row_ctr, col_ctr;
  logic [8:0] coeff_ctr;
  logic [CW-1:0] acc_reg;

  always_ff @(posedge clk) begin
    tr_shake_start <= 1'b0;
    mu_shake_start <= 1'b0;
    expA_start <= 1'b0;
    sib_start <= 1'b0;
    unpack_h_start <= 1'b0;
    fwd_start <= 1'b0;
    inv_start <= 1'b0;
    final_shake_start <= 1'b0;
    done <= 1'b0;

    if (reset) begin
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: if (start) begin
          tr_shake_msg_in <= '0;
          tr_shake_msg_in[8*(32+K*320)-1:0] <= pk_in;
          state <= S_START_TR;
        end

        S_START_TR: begin tr_shake_start <= 1'b1; state <= S_WAIT_TR; end
        S_WAIT_TR: if (tr_shake_done) begin
          tr_reg[511:0] <= {448'b0, tr_shake_out};
          mu_shake_msg_in <= '0;
          mu_shake_msg_in[511:0] <= tr_shake_out;
          mu_shake_msg_in[8*(64+MSG_BYTES)-1:512] <= m_in;
          state <= S_START_MU;
        end

        S_START_MU: begin mu_shake_start <= 1'b1; state <= S_WAIT_MU; end
        S_WAIT_MU: if (mu_shake_done) begin
          mu_reg[511:0] <= {448'b0, mu_shake_out};
          state <= S_START_PARALLEL_A;
        end

        S_START_PARALLEL_A: begin expA_start <= 1'b1; state <= S_WAIT_A; end
        S_WAIT_A: if (expA_done) state <= S_START_SIB;

        S_START_SIB: begin sib_start <= 1'b1; state <= S_WAIT_SIB; end
        S_WAIT_SIB: if (sib_done) state <= S_START_UNPACK_H;

        S_START_UNPACK_H: begin unpack_h_start <= 1'b1; state <= S_WAIT_UNPACK_H; end
        S_WAIT_UNPACK_H: if (unpack_h_done) begin
          fwd_in <= c_zq;
          state <= S_FWD_C_START;
        end

        S_FWD_C_START: begin fwd_start <= 1'b1; state <= S_FWD_C_WAIT; end
        S_FWD_C_WAIT: if (fwd_done) begin
          c_hat <= fwd_out;
          z_ctr <= 4'd0;
          fwd_in <= z_zq[0];
          state <= S_FWD_Z_START;
        end

        S_FWD_Z_START: begin fwd_start <= 1'b1; state <= S_FWD_Z_WAIT; end
        S_FWD_Z_WAIT: if (fwd_done) state <= S_FWD_Z_STORE;
        S_FWD_Z_STORE: begin
          z_hat[z_ctr] <= fwd_out;
          if (z_ctr == L-1) begin
            t1_ctr <= 4'd0;
            fwd_in <= t1_scaled[0];
            state <= S_FWD_T1_START;
          end else begin
            z_ctr <= z_ctr + 4'd1;
            fwd_in <= z_zq[z_ctr+4'd1];
            state <= S_FWD_Z_START;
          end
        end

        S_FWD_T1_START: begin fwd_start <= 1'b1; state <= S_FWD_T1_WAIT; end
        S_FWD_T1_WAIT: if (fwd_done) state <= S_FWD_T1_STORE;
        S_FWD_T1_STORE: begin
          t1_hat[t1_ctr] <= fwd_out;
          if (t1_ctr == K-1) begin
            row_ctr <= 4'd0;
            state <= S_MM_ROW_INIT;
          end else begin
            t1_ctr <= t1_ctr + 4'd1;
            fwd_in <= t1_scaled[t1_ctr+4'd1];
            state <= S_FWD_T1_START;
          end
        end

        // --- Matriisikertolasku: Az_hat[row] = sum_i(A[row][i]*z_hat[i]) - t1_hat[row]*c_hat ---
        S_MM_ROW_INIT: begin
          col_ctr <= 4'd0;
          coeff_ctr <= 9'd0;
          acc_reg <= '0;
          state <= S_MM_ACC_SETUP;
        end

        S_MM_ACC_SETUP: begin
          mm_a_in <= A_hat[(row_ctr*L+col_ctr)*256*CW + coeff_ctr*CW +: CW];
          mm_b_in <= z_hat[col_ctr][coeff_ctr*CW +: CW];
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
            col_ctr <= 4'd0;
            state <= S_MM_SUB_SETUP;
          end else begin
            col_ctr <= col_ctr + 4'd1;
            state <= S_MM_ACC_SETUP;
          end
        end

        S_MM_SUB_SETUP: begin
          mm_a_in <= t1_hat[row_ctr][coeff_ctr*CW +: CW];
          mm_b_in <= c_hat[coeff_ctr*CW +: CW];
          state <= S_MM_SUB_CAPTURE;
        end

        S_MM_SUB_CAPTURE: begin
          begin
            logic signed [CW:0] diff_wide;
            diff_wide = $signed({1'b0, acc_reg}) - $signed({1'b0, mm_out});
            Az_hat[row_ctr][coeff_ctr*CW +: CW] <= (diff_wide < 0) ? (diff_wide + Q) : diff_wide[CW-1:0];
          end
          if (coeff_ctr == 9'd255) begin
            if (row_ctr == K-1) begin
              row_ctr <= 4'd0;
              state <= S_INV_START;
            end else begin
              row_ctr <= row_ctr + 4'd1;
              coeff_ctr <= 9'd0;
              state <= S_MM_ROW_INIT;
            end
          end else begin
            coeff_ctr <= coeff_ctr + 9'd1;
            state <= S_MM_ROW_INIT;
          end
        end

        S_INV_START: begin
          inv_in <= Az_hat[row_ctr];
          inv_start <= 1'b1;
          state <= S_INV_WAIT;
        end
        S_INV_WAIT: if (inv_done) state <= S_INV_STORE;
        S_INV_STORE: begin
          Az_minus_ct1[row_ctr] <= inv_out;
          if (row_ctr == K-1) begin
            final_shake_msg_in <= '0;
            final_shake_msg_in[511:0] <= mu_shake_out;
            state <= S_FINAL_SHAKE_START;
          end else begin
            row_ctr <= row_ctr + 4'd1;
            state <= S_INV_START;
          end
        end

        S_FINAL_SHAKE_START: begin
          final_shake_msg_in[8*(64+K*128)-1:512] <= w_prime_bytes;
          final_shake_start <= 1'b1;
          state <= S_FINAL_SHAKE_WAIT;
        end
        S_FINAL_SHAKE_WAIT: if (final_shake_done) state <= S_COMPARE;

        S_COMPARE: begin
          verify_ok <= (final_shake_out == c_tilde);
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
