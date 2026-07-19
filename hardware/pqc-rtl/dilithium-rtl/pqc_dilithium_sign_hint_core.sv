// pqc_dilithium_sign_hint_core.sv
//
// M5-DILITHIUM-001 DK6 S6: hintien muodostus. K=6 polynomia.
//
// dilithium-py:n oma kaava:
//   c_s2 = s2_hat.scale(c_hat).from_ntt()
//   r0 = (w - c_s2).low_bits(alpha)
//   reject1 = r0.check_norm_bound(GAMMA2-BETA)
//   c_t0 = t0_hat.scale(c_hat).from_ntt()
//   reject2 = c_t0.check_norm_bound(GAMMA2)
//   h = (-c_t0).make_hint(w-c_s2+c_t0, alpha)
//   reject3 = h.sum_hint() > OMEGA
//
// Uudelleenkayttaa: forward/inverse-NTT (DK1), Barrett (DK1), Decompose
// (DK5), MakeHint (uusi, jo todistettu erikseen).

`timescale 1ns/1ps

module pqc_dilithium_sign_hint_core #(
    parameter int Q = 8380417,
    parameter int CW = 23,
    parameter int K = 6,
    parameter int GAMMA2 = 261888,
    parameter int BETA = 196,
    parameter int ALPHA = 523776,
    parameter int OMEGA = 55
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [K*256*CW-1:0] w_in_flat,
    input  logic [K*256*CW-1:0] s2_in_flat,   // Zq-edustajina [0,Q)
    input  logic [K*256*CW-1:0] t0_in_flat,   // Zq-edustajina [0,Q)
    input  logic [256*8-1:0] c_in_flat,        // SampleInBall:n raaka tulos (-1,0,1)

    output logic done,
    output logic [K*256-1:0] h_out_flat,
    output logic reject   // reject1 || reject2 || reject3
);

  localparam int R0_BOUND = GAMMA2 - BETA;
  localparam int CT0_BOUND = GAMMA2;

  logic [256*CW-1:0] s2_hat [0:K-1];
  logic [256*CW-1:0] t0_hat [0:K-1];
  logic [256*CW-1:0] c_hat;
  logic [256*CW-1:0] c_zq;

  logic [256*CW-1:0] c_s2_hat [0:K-1];
  logic [256*CW-1:0] c_t0_hat [0:K-1];
  logic [256*CW-1:0] c_s2_raw [0:K-1];
  logic [256*CW-1:0] c_t0_raw [0:K-1];

  genvar gci;
  generate
    for (gci = 0; gci < 256; gci++) begin : g_c_conv
      wire signed [7:0] raw = c_in_flat[gci*8 +: 8];
      assign c_zq[gci*CW +: CW] = (raw < 0) ? (Q + raw) : raw;
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

  typedef enum logic [4:0] {
    S_IDLE,
    S_FWD_S2_START, S_FWD_S2_WAIT, S_FWD_S2_STORE,
    S_FWD_T0_START, S_FWD_T0_WAIT, S_FWD_T0_STORE,
    S_FWD_C_START, S_FWD_C_WAIT, S_FWD_C_STORE,
    S_MUL_S2_SETUP, S_MUL_S2_CAPTURE, S_MUL_S2_NEXT,
    S_MUL_T0_SETUP, S_MUL_T0_CAPTURE, S_MUL_T0_NEXT,
    S_INV_S2_START, S_INV_S2_WAIT, S_INV_S2_STORE,
    S_INV_T0_START, S_INV_T0_WAIT, S_INV_T0_STORE,
    S_DONE
  } state_e;
  state_e state;

  logic [3:0] ctr, row_ctr;
  logic [8:0] coeff_ctr;

  always_ff @(posedge clk) begin
    fwd_start <= 1'b0;
    inv_start <= 1'b0;
    done <= 1'b0;

    if (reset) begin
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: if (start) begin
          ctr <= 4'd0;
          state <= S_FWD_S2_START;
        end

        S_FWD_S2_START: begin
          fwd_in <= s2_in_flat[ctr*256*CW +: 256*CW];
          fwd_start <= 1'b1;
          state <= S_FWD_S2_WAIT;
        end
        S_FWD_S2_WAIT: if (fwd_done) state <= S_FWD_S2_STORE;
        S_FWD_S2_STORE: begin
          s2_hat[ctr] <= fwd_out;
          if (ctr == K-1) begin
            ctr <= 4'd0;
            state <= S_FWD_T0_START;
          end else begin
            ctr <= ctr + 4'd1;
            state <= S_FWD_S2_START;
          end
        end

        S_FWD_T0_START: begin
          fwd_in <= t0_in_flat[ctr*256*CW +: 256*CW];
          fwd_start <= 1'b1;
          state <= S_FWD_T0_WAIT;
        end
        S_FWD_T0_WAIT: if (fwd_done) state <= S_FWD_T0_STORE;
        S_FWD_T0_STORE: begin
          t0_hat[ctr] <= fwd_out;
          if (ctr == K-1) begin
            state <= S_FWD_C_START;
          end else begin
            ctr <= ctr + 4'd1;
            state <= S_FWD_T0_START;
          end
        end

        S_FWD_C_START: begin
          fwd_in <= c_zq;
          fwd_start <= 1'b1;
          state <= S_FWD_C_WAIT;
        end
        S_FWD_C_WAIT: if (fwd_done) state <= S_FWD_C_STORE;
        S_FWD_C_STORE: begin
          c_hat <= fwd_out;
          row_ctr <= 4'd0;
          coeff_ctr <= 9'd0;
          state <= S_MUL_S2_SETUP;
        end

        // --- c_s2_hat = s2_hat * c_hat (pisteittain) ---
        S_MUL_S2_SETUP: begin
          mm_a_in <= s2_hat[row_ctr][coeff_ctr*CW +: CW];
          mm_b_in <= c_hat[coeff_ctr*CW +: CW];
          state <= S_MUL_S2_CAPTURE;
        end
        S_MUL_S2_CAPTURE: begin
          c_s2_hat[row_ctr][coeff_ctr*CW +: CW] <= mm_out;
          state <= S_MUL_S2_NEXT;
        end
        S_MUL_S2_NEXT: begin
          if (coeff_ctr == 9'd255) begin
            if (row_ctr == K-1) begin
              row_ctr <= 4'd0;
              coeff_ctr <= 9'd0;
              state <= S_MUL_T0_SETUP;
            end else begin
              row_ctr <= row_ctr + 4'd1;
              coeff_ctr <= 9'd0;
              state <= S_MUL_S2_SETUP;
            end
          end else begin
            coeff_ctr <= coeff_ctr + 9'd1;
            state <= S_MUL_S2_SETUP;
          end
        end

        // --- c_t0_hat = t0_hat * c_hat (pisteittain) ---
        S_MUL_T0_SETUP: begin
          mm_a_in <= t0_hat[row_ctr][coeff_ctr*CW +: CW];
          mm_b_in <= c_hat[coeff_ctr*CW +: CW];
          state <= S_MUL_T0_CAPTURE;
        end
        S_MUL_T0_CAPTURE: begin
          c_t0_hat[row_ctr][coeff_ctr*CW +: CW] <= mm_out;
          state <= S_MUL_T0_NEXT;
        end
        S_MUL_T0_NEXT: begin
          if (coeff_ctr == 9'd255) begin
            if (row_ctr == K-1) begin
              row_ctr <= 4'd0;
              state <= S_INV_S2_START;
            end else begin
              row_ctr <= row_ctr + 4'd1;
              coeff_ctr <= 9'd0;
              state <= S_MUL_T0_SETUP;
            end
          end else begin
            coeff_ctr <= coeff_ctr + 9'd1;
            state <= S_MUL_T0_SETUP;
          end
        end

        S_INV_S2_START: begin
          inv_in <= c_s2_hat[row_ctr];
          inv_start <= 1'b1;
          state <= S_INV_S2_WAIT;
        end
        S_INV_S2_WAIT: if (inv_done) state <= S_INV_S2_STORE;
        S_INV_S2_STORE: begin
          c_s2_raw[row_ctr] <= inv_out;
          if (row_ctr == K-1) begin
            row_ctr <= 4'd0;
            state <= S_INV_T0_START;
          end else begin
            row_ctr <= row_ctr + 4'd1;
            state <= S_INV_S2_START;
          end
        end

        S_INV_T0_START: begin
          inv_in <= c_t0_hat[row_ctr];
          inv_start <= 1'b1;
          state <= S_INV_T0_WAIT;
        end
        S_INV_T0_WAIT: if (inv_done) state <= S_INV_T0_STORE;
        S_INV_T0_STORE: begin
          c_t0_raw[row_ctr] <= inv_out;
          if (row_ctr == K-1) begin
            state <= S_DONE;
          end else begin
            row_ctr <= row_ctr + 4'd1;
            state <= S_INV_T0_START;
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

  // --- w_minus_cs2 = w - c_s2 mod Q (kombinatorinen) ---
  logic [256*CW-1:0] w_minus_cs2 [0:K-1];
  logic [256*CW-1:0] w_minus_cs2_plus_ct0 [0:K-1];
  logic [256*CW-1:0] neg_ct0 [0:K-1];

  genvar gi, gj;
  generate
    for (gi = 0; gi < K; gi++) begin : g_wsub_row
      for (gj = 0; gj < 256; gj++) begin : g_wsub_coeff
        wire signed [CW+1:0] w_s = $signed({2'b0, w_in_flat[(gi*256+gj)*CW +: CW]});
        wire signed [CW+1:0] cs2_s = $signed({2'b0, c_s2_raw[gi][gj*CW +: CW]});
        wire signed [CW+1:0] ct0_s = $signed({2'b0, c_t0_raw[gi][gj*CW +: CW]});

        wire signed [CW+1:0] diff1 = w_s - cs2_s;                 // valilla (-Q,Q)
        wire signed [CW+1:0] diff1_norm = (diff1 < 0) ? (diff1 + Q) : diff1;

        wire signed [CW+1:0] sum2 = w_s - cs2_s + ct0_s;          // valilla (-2Q,2Q)
        wire signed [CW+1:0] sum2_step1 = (sum2 < 0) ? (sum2 + Q) : sum2;
        wire signed [CW+1:0] sum2_norm = (sum2_step1 >= Q) ? (sum2_step1 - Q)
                                          : (sum2_step1 < 0) ? (sum2_step1 + Q) : sum2_step1;

        wire [CW-1:0] neg_ct0_val = (c_t0_raw[gi][gj*CW +: CW] == 0) ? {CW{1'b0}} : (Q - c_t0_raw[gi][gj*CW +: CW]);

        assign w_minus_cs2[gi][gj*CW +: CW] = diff1_norm[CW-1:0];
        assign w_minus_cs2_plus_ct0[gi][gj*CW +: CW] = sum2_norm[CW-1:0];
        assign neg_ct0[gi][gj*CW +: CW] = neg_ct0_val;
      end
    end
  endgenerate

  // --- r0 = LowBits(w_minus_cs2) + normitarkistus (reject1) ---
  logic [K-1:0] reject1_per_row [0:255];
  logic [K-1:0] reject2_per_row [0:255];

  generate
    for (gi = 0; gi < K; gi++) begin : g_r0_row
      for (gj = 0; gj < 256; gj++) begin : g_r0_coeff
        logic [3:0] r1_dummy;
        logic signed [CW-1:0] r0_val;
        pqc_dilithium_decompose #(.Q(Q), .CW(CW), .ALPHA(ALPHA)) decomp_r0 (
          .r_in(w_minus_cs2[gi][gj*CW +: CW]), .r1_out(r1_dummy), .r0_out(r0_val)
        );
        wire signed [CW-1:0] abs_r0 = (r0_val < 0) ? -r0_val : r0_val;
        assign reject1_per_row[gj][gi] = (abs_r0 >= R0_BOUND);

        // c_t0 oman normitarkistuksen keskitetty edustaja
        wire signed [CW:0] ct0_centered = ($signed({1'b0,c_t0_raw[gi][gj*CW+:CW]}) > (Q-1)/2)
                                            ? ($signed({1'b0,c_t0_raw[gi][gj*CW+:CW]}) - Q)
                                            : $signed({1'b0,c_t0_raw[gi][gj*CW+:CW]});
        wire signed [CW:0] abs_ct0 = (ct0_centered < 0) ? -ct0_centered : ct0_centered;
        assign reject2_per_row[gj][gi] = (abs_ct0 >= CT0_BOUND);

        // --- MakeHint(-c_t0, w-c_s2+c_t0, alpha) ---
        pqc_dilithium_make_hint #(.Q(Q), .CW(CW), .ALPHA(ALPHA)) mh_dut (
          .z_in(neg_ct0[gi][gj*CW +: CW]),
          .r_in(w_minus_cs2_plus_ct0[gi][gj*CW +: CW]),
          .h_out(h_out_flat[gi*256+gj])
        );
      end
    end
  endgenerate

  logic reject1, reject2, reject3;
  integer hint_sum;
  always_comb begin
    reject1 = 1'b0;
    reject2 = 1'b0;
    for (int j = 0; j < 256; j++) begin
      if (reject1_per_row[j] != '0) reject1 = 1'b1;
      if (reject2_per_row[j] != '0) reject2 = 1'b1;
    end
    hint_sum = 0;
    for (int idx = 0; idx < K*256; idx++) begin
      hint_sum = hint_sum + h_out_flat[idx];
    end
    reject3 = (hint_sum > OMEGA);
  end

  assign reject = reject1 || reject2 || reject3;

endmodule
