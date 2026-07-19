// pqc_dilithium_sign_top2.sv
//
// M5-DILITHIUM-001 DK6 S7: Sign_internal:n hylkayssilmukka,
// UUDELLEEN RAKENNETTU EKSPLISIITTISENA PIPELINE-FSM:na (kayttajan
// oma ehdotus). JOKAINEN vaihe alkaa rekisterista ja paattyy
// rekisteriin - EI yhtaan suoraa moduulista-moduuliin-kytkentaa ilman
// valissa olevaa rekisteria. Sama periaate joka ratkaisi Verifyn oman
// simulointijumin (unpack_z_vector+Zq-muunnos), sovellettuna nyt
// KAIKKIIN S3-S6-vaiheiden valeihin ETUKATEEN, ei jalkikateen
// paikattuna.

`timescale 1ns/1ps

module pqc_dilithium_sign_top2 #(
    parameter int Q = 8380417,
    parameter int CW = 23,
    parameter int ZW = 24,
    parameter int K = 6,
    parameter int L = 5,
    parameter int TAU = 49,
    parameter int GAMMA1 = 524288,
    parameter int BETA = 196,
    parameter int OMEGA = 55,
    parameter int MSG_BYTES = 30
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [255:0] rho_in,
    input  logic [255:0] k_key_in,
    input  logic [511:0] tr_in,
    input  logic [L*256*CW-1:0] s1_in_flat,
    input  logic [K*256*CW-1:0] s2_in_flat,
    input  logic [K*256*CW-1:0] t0_in_flat,
    input  logic [8*MSG_BYTES-1:0] m_in,
    input  logic [255:0] rnd_in,

    output logic done,
    output logic [L*256*ZW-1:0] z_out_flat,
    output logic [K*256-1:0] h_out_flat,
    output logic [383:0] c_tilde_out,
    output logic [15:0] kappa_final_out,
    output logic [7:0] iter_count_out
);

  // === REKISTERIT jokaisen vaiheen valissa (PIPELINE-periaate) ===
  logic [511:0] mu_reg;
  logic [511:0] rho_prime_reg;
  logic [K*L*256*CW-1:0] A_hat_reg;
  logic [L*256*ZW-1:0] y_reg;          // etumerkillinen, ExpandMask:n oma ulostulo
  logic [L*256*CW-1:0] y_zq_reg;        // Zq-edustaja, w_core:n omaa syotetta varten
  logic [K*256*CW-1:0] w_reg;
  logic [383:0] c_tilde_reg;
  logic [256*8-1:0] c_reg;              // SampleInBall:n raaka tulos
  logic [L*256*ZW-1:0] z_reg;
  logic z_reject_reg;
  logic [K*256-1:0] h_reg;
  logic h_reject_reg;

  logic [15:0] kappa_reg;
  logic [7:0] iter_ctr;

  // === mu = H(tr||m,64) ===
  logic mu_start, mu_done;
  logic [8*136-1:0] mu_msg_in;
  logic [511:0] mu_out;
  pqc_shake256 #(.MAX_BLOCKS(1), .MAX_OUT_BYTES(64)) mu_dut (
    .clk(clk), .reset(reset), .start(mu_start),
    .msg_in(mu_msg_in), .msg_len_bytes(16'(64+MSG_BYTES)), .out_len_bytes(16'd64),
    .out_data(mu_out), .done(mu_done)
  );

  // === rho_prime = H(K||rnd||mu,64) ===
  logic rp_start, rp_done;
  logic [8*136-1:0] rp_msg_in;
  logic [511:0] rp_out;
  pqc_shake256 #(.MAX_BLOCKS(1), .MAX_OUT_BYTES(64)) rp_dut (
    .clk(clk), .reset(reset), .start(rp_start),
    .msg_in(rp_msg_in), .msg_len_bytes(16'd128), .out_len_bytes(16'd64),
    .out_data(rp_out), .done(rp_done)
  );

  // === A_hat = ExpandA(rho), KERRAN ===
  logic expA_start, expA_done;
  logic [K*L*256*CW-1:0] A_hat_out;
  pqc_dilithium_expand_a #(.Q(Q), .CW(CW), .K(K), .L(L)) expA_dut (
    .clk(clk), .reset(reset), .start(expA_start),
    .rho_in(rho_in), .done(expA_done), .A_out_flat(A_hat_out)
  );

  // === y = ExpandMask(rho_prime, kappa) - SYOTE: rho_prime_reg (REKISTERI) ===
  logic em_start, em_done;
  logic [L*256*ZW-1:0] y_out;
  pqc_dilithium_expand_mask_vector #(.GAMMA1(GAMMA1), .ZW(ZW), .L(L)) em_dut (
    .clk(clk), .reset(reset), .start(em_start),
    .rho_prime_in(rho_prime_reg), .kappa_in(kappa_reg),
    .done(em_done), .y_out_flat(y_out)
  );

  // === y etumerkillinen -> Zq (kombinatorinen, SYOTE: y_reg REKISTERI) ===
  logic [L*256*CW-1:0] y_zq_out;
  genvar gyi, gyj;
  generate
    for (gyi = 0; gyi < L; gyi++) begin : g_y_row
      for (gyj = 0; gyj < 256; gyj++) begin : g_y_coeff
        wire signed [ZW-1:0] raw = y_reg[(gyi*256+gyj)*ZW +: ZW];
        assign y_zq_out[(gyi*256+gyj)*CW +: CW] = (raw < 0) ? (Q + raw) : raw[CW-1:0];
      end
    end
  endgenerate

  // === w = NTT^-1(A_hat@NTT(y)) - SYOTE: A_hat_reg, y_zq_reg (REKISTERIT) ===
  logic w_start, w_done;
  logic [K*256*CW-1:0] w_out;
  pqc_dilithium_sign_w_core #(.Q(Q), .CW(CW), .K(K), .L(L)) w_dut (
    .clk(clk), .reset(reset), .start(w_start),
    .A_hat_in(A_hat_reg), .y_in_flat(y_zq_reg),
    .done(w_done), .w_out_flat(w_out)
  );

  // === Challenge - SYOTE: w_reg, mu_reg (REKISTERIT) ===
  logic ch_start, ch_done;
  logic [383:0] c_tilde_out_w;
  logic [256*8-1:0] c_out_w;
  pqc_dilithium_sign_challenge #(.Q(Q), .CW(CW), .K(K), .TAU(TAU)) ch_dut (
    .clk(clk), .reset(reset), .start(ch_start),
    .w_in_flat(w_reg), .mu_in(mu_reg),
    .done(ch_done), .c_tilde_out(c_tilde_out_w), .c_out_flat(c_out_w)
  );

  // === z + normitarkistus - SYOTE: s1_in_flat(portti), y_reg, c_reg (REKISTERIT) ===
  logic z_start, z_done, z_reject_w;
  logic [L*256*ZW-1:0] z_out_w;
  pqc_dilithium_sign_z_core #(.Q(Q), .CW(CW), .L(L), .GAMMA1(GAMMA1), .BETA(BETA), .ZW(ZW)) z_dut (
    .clk(clk), .reset(reset), .start(z_start),
    .s1_in_flat(s1_in_flat), .y_in_flat(y_reg), .c_in_flat(c_reg),
    .done(z_done), .z_out_flat(z_out_w), .reject(z_reject_w)
  );

  // === Hintien muodostus - SYOTE: w_reg, s2_in_flat(portti), t0_in_flat(portti), c_reg (REKISTERIT) ===
  logic h_start, h_done, h_reject_w;
  logic [K*256-1:0] h_out_w;
  pqc_dilithium_sign_hint_core #(.Q(Q), .CW(CW), .K(K)) h_dut (
    .clk(clk), .reset(reset), .start(h_start),
    .w_in_flat(w_reg), .s2_in_flat(s2_in_flat), .t0_in_flat(t0_in_flat), .c_in_flat(c_reg),
    .done(h_done), .h_out_flat(h_out_w), .reject(h_reject_w)
  );

  typedef enum logic [4:0] {
    S_IDLE,
    S_START_MU, S_WAIT_MU,
    S_START_RP, S_WAIT_RP,
    S_START_A, S_WAIT_A,
    S_LOOP_START_EM, S_LOOP_WAIT_EM,
    S_LOOP_START_W, S_LOOP_WAIT_W,
    S_LOOP_START_CH, S_LOOP_WAIT_CH,
    S_LOOP_START_Z, S_LOOP_WAIT_Z,
    S_LOOP_CHECK_Z,
    S_LOOP_START_H, S_LOOP_WAIT_H,
    S_LOOP_CHECK_H,
    S_DONE
  } state_e;
  state_e state;

  always_ff @(posedge clk) begin
    mu_start <= 1'b0;
    rp_start <= 1'b0;
    expA_start <= 1'b0;
    em_start <= 1'b0;
    w_start <= 1'b0;
    ch_start <= 1'b0;
    z_start <= 1'b0;
    h_start <= 1'b0;
    done <= 1'b0;

    if (reset) begin
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: if (start) begin
          mu_msg_in <= '0;
          mu_msg_in[511:0] <= tr_in;
          mu_msg_in[8*(64+MSG_BYTES)-1:512] <= m_in;
          state <= S_START_MU;
        end

        S_START_MU: begin mu_start <= 1'b1; state <= S_WAIT_MU; end
        S_WAIT_MU: if (mu_done) begin
          mu_reg <= mu_out;  // REKISTERI 1: mu
          rp_msg_in <= '0;
          rp_msg_in[255:0] <= k_key_in;
          rp_msg_in[511:256] <= rnd_in;
          rp_msg_in[1023:512] <= mu_out;
          state <= S_START_RP;
        end

        S_START_RP: begin rp_start <= 1'b1; state <= S_WAIT_RP; end
        S_WAIT_RP: if (rp_done) begin
          rho_prime_reg <= rp_out;  // REKISTERI 2: rho_prime
          state <= S_START_A;
        end

        S_START_A: begin expA_start <= 1'b1; state <= S_WAIT_A; end
        S_WAIT_A: if (expA_done) begin
          A_hat_reg <= A_hat_out;  // REKISTERI 3: A_hat (KERRAN koko silmukalle)
          kappa_reg <= 16'd0;
          iter_ctr <= 8'd0;
          state <= S_LOOP_START_EM;
        end

        S_LOOP_START_EM: begin em_start <= 1'b1; state <= S_LOOP_WAIT_EM; end
        S_LOOP_WAIT_EM: if (em_done) begin
          y_reg <= y_out;  // REKISTERI 4: y (etumerkillinen)
          state <= S_LOOP_START_W;
        end

        S_LOOP_START_W: begin
          y_zq_reg <= y_zq_out;  // REKISTERI 5: y_zq (kombinatorinen muunnos, rekisteroity ENNEN w_core:n kayttoa)
          w_start <= 1'b1;
          state <= S_LOOP_WAIT_W;
        end
        S_LOOP_WAIT_W: if (w_done) begin
          w_reg <= w_out;  // REKISTERI 6: w
          state <= S_LOOP_START_CH;
        end

        S_LOOP_START_CH: begin ch_start <= 1'b1; state <= S_LOOP_WAIT_CH; end
        S_LOOP_WAIT_CH: if (ch_done) begin
          c_tilde_reg <= c_tilde_out_w;  // REKISTERI 7a: c_tilde
          c_reg <= c_out_w;              // REKISTERI 7b: c (raaka)
          state <= S_LOOP_START_Z;
        end

        S_LOOP_START_Z: begin z_start <= 1'b1; state <= S_LOOP_WAIT_Z; end
        S_LOOP_WAIT_Z: if (z_done) begin
          z_reg <= z_out_w;              // REKISTERI 8a: z
          z_reject_reg <= z_reject_w;    // REKISTERI 8b: z_reject
          state <= S_LOOP_CHECK_Z;
        end

        S_LOOP_CHECK_Z: begin
          if (z_reject_reg) begin
            kappa_reg <= kappa_reg + L[15:0];
            iter_ctr <= iter_ctr + 8'd1;
            state <= S_LOOP_START_EM;
          end else begin
            state <= S_LOOP_START_H;
          end
        end

        S_LOOP_START_H: begin h_start <= 1'b1; state <= S_LOOP_WAIT_H; end
        S_LOOP_WAIT_H: if (h_done) begin
          h_reg <= h_out_w;              // REKISTERI 9a: h
          h_reject_reg <= h_reject_w;    // REKISTERI 9b: h_reject
          state <= S_LOOP_CHECK_H;
        end

        S_LOOP_CHECK_H: begin
          if (h_reject_reg) begin
            kappa_reg <= kappa_reg + L[15:0];
            iter_ctr <= iter_ctr + 8'd1;
            state <= S_LOOP_START_EM;
          end else begin
            state <= S_DONE;
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

  assign z_out_flat = z_reg;
  assign h_out_flat = h_reg;
  assign c_tilde_out = c_tilde_reg;
  assign kappa_final_out = kappa_reg;
  assign iter_count_out = iter_ctr;

endmodule
