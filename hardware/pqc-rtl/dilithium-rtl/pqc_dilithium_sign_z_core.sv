// pqc_dilithium_sign_z_core.sv
//
// M5-DILITHIUM-001 DK6 S5: z = y + c*s1, normitarkistus (FIPS 204
// Algoritmi 7:n oma z-vaihe). L=5 polynomia.
//
// dilithium-py:n oma kaava:
//   c_s1 = s1_hat.scale(c_hat).from_ntt()
//   z = y + c_s1
//   reject jos z.check_norm_bound(GAMMA1-BETA) millekaan kertoimelle
//
// check_norm_bound(n,b,q): x=n%q; centered=(x>(Q-1)/2)?(x-Q):x;
// return abs(centered)>=b. TODENNETTU EMPIIRISESTI 100000 satunnaisella
// arvolla etta tama yksinkertaistettu muoto tasmaa taydellisesti
// dilithium-py:n omaan bittikikkaan.

`timescale 1ns/1ps

module pqc_dilithium_sign_z_core #(
    parameter int Q = 8380417,
    parameter int CW = 23,
    parameter int L = 5,
    parameter int GAMMA1 = 524288,
    parameter int BETA = 196,
    parameter int ZW = 24
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [L*256*CW-1:0] s1_in_flat,   // s1 Zq-edustajina [0,Q)
    input  logic [L*256*ZW-1:0] y_in_flat,     // y etumerkillisena (-(GAMMA1-1),GAMMA1]
    input  logic [256*8-1:0] c_in_flat,        // SampleInBall:n raaka tulos (-1,0,1)

    output logic done,
    output logic [L*256*ZW-1:0] z_out_flat,    // z etumerkillisena
    output logic reject                          // 1 = normitarkistus epaonnistui, hylattava
);

  localparam int BOUND = GAMMA1 - BETA;

  logic [256*CW-1:0] s1_hat [0:L-1];
  logic [256*CW-1:0] c_hat;
  logic [256*CW-1:0] c_s1_hat [0:L-1];
  logic [256*CW-1:0] c_s1_raw [0:L-1];
  logic [256*CW-1:0] c_zq;

  generate
    genvar gci;
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

  typedef enum logic [3:0] {
    S_IDLE,
    S_FWD_S1_START, S_FWD_S1_WAIT, S_FWD_S1_STORE,
    S_FWD_C_START, S_FWD_C_WAIT, S_FWD_C_STORE,
    S_MUL_SETUP, S_MUL_CAPTURE, S_MUL_NEXT,
    S_INV_START, S_INV_WAIT, S_INV_STORE,
    S_DONE
  } state_e;
  state_e state;

  logic [3:0] s1_ctr, row_ctr;
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
          s1_ctr <= 4'd0;
          state <= S_FWD_S1_START;
        end

        S_FWD_S1_START: begin
          fwd_in <= s1_in_flat[s1_ctr*256*CW +: 256*CW];
          fwd_start <= 1'b1;
          state <= S_FWD_S1_WAIT;
        end
        S_FWD_S1_WAIT: if (fwd_done) state <= S_FWD_S1_STORE;
        S_FWD_S1_STORE: begin
          s1_hat[s1_ctr] <= fwd_out;
          if (s1_ctr == L-1) begin
            state <= S_FWD_C_START;
          end else begin
            s1_ctr <= s1_ctr + 4'd1;
            state <= S_FWD_S1_START;
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
          coeff_ctr <= 9'd0;
          state <= S_MUL_SETUP;
        end

        // --- c_s1_hat[row] = s1_hat[row] * c_hat (pisteittain) ---
        S_MUL_SETUP: begin
          mm_a_in <= s1_hat[row_ctr][coeff_ctr*CW +: CW];
          mm_b_in <= c_hat[coeff_ctr*CW +: CW];
          state <= S_MUL_CAPTURE;
        end

        S_MUL_CAPTURE: begin
          c_s1_hat[row_ctr][coeff_ctr*CW +: CW] <= mm_out;
          state <= S_MUL_NEXT;
        end

        S_MUL_NEXT: begin
          if (coeff_ctr == 9'd255) begin
            if (row_ctr == L-1) begin
              row_ctr <= 4'd0;
              state <= S_INV_START;
            end else begin
              row_ctr <= row_ctr + 4'd1;
              coeff_ctr <= 9'd0;
              state <= S_MUL_SETUP;
            end
          end else begin
            coeff_ctr <= coeff_ctr + 9'd1;
            state <= S_MUL_SETUP;
          end
        end

        // c_hat on nyt oikein NTT-domainissa (S_FWD_C_STORE:sta) -
        // pisteittainen kertolasku s1_hat*c_hat on siis oikein.

        S_INV_START: begin
          inv_in <= c_s1_hat[row_ctr];
          inv_start <= 1'b1;
          state <= S_INV_WAIT;
        end
        S_INV_WAIT: if (inv_done) state <= S_INV_STORE;
        S_INV_STORE: begin
          c_s1_raw[row_ctr] <= inv_out;
          if (row_ctr == L-1) begin
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

  // --- z = y + c_s1 (kombinatorinen), ja normitarkistus ---
  logic [L-1:0] reject_per_poly [0:255];
  genvar gzi, gzj;
  generate
    for (gzi = 0; gzi < L; gzi++) begin : g_z_row
      for (gzj = 0; gzj < 256; gzj++) begin : g_z_coeff
        wire signed [ZW-1:0] y_val = y_in_flat[(gzi*256+gzj)*ZW +: ZW];
        wire signed [CW-1:0] cs1_val = c_s1_raw[gzi][gzj*CW +: CW];  // jo Zq [0,Q)
        wire signed [ZW:0] sum_wide = y_val + $signed({1'b0, cs1_val});
        // Bring into Zq [0,Q) representative (matching Python's own "n % q" preprocessing)
        wire signed [ZW:0] sum_mod_q = ((sum_wide % Q) + Q) % Q;
        wire signed [ZW:0] centered = (sum_mod_q > (Q-1)/2) ? (sum_mod_q - Q) : sum_mod_q;
        wire signed [ZW:0] abs_centered = (centered < 0) ? -centered : centered;

        assign z_out_flat[(gzi*256+gzj)*ZW +: ZW] = sum_mod_q[ZW-1:0];
        assign reject_per_poly[gzj][gzi] = (abs_centered >= BOUND);
      end
    end
  endgenerate

  // reject = OR kaikkien L*256 tarkistuksen yli
  always_comb begin
    reject = 1'b0;
    for (int j = 0; j < 256; j++) begin
      if (reject_per_poly[j] != '0) reject = 1'b1;
    end
  end

endmodule
