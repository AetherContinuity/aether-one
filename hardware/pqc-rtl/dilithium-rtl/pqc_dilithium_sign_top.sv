// pqc_dilithium_sign_top.sv
//
// M5-DILITHIUM-001 DK6 S7: Sign_internal:n koko hylkayssilmukka
// (FIPS 204 Algoritmi 7). Yhdistaa KAIKKI jo erikseen todistetut
// S1-S6-palikat yhdeksi orkestroinniksi:
//
//   mu = H(tr||m, 64)
//   rho_prime = H(K||rnd||mu, 64)
//   A_hat = ExpandA(rho)  [KERRAN, uudelleenkaytetaan joka kierroksella]
//   kappa = 0
//   loop:
//     y = ExpandMask(rho_prime, kappa)          [S1+S2]
//     w = NTT^-1(A_hat@NTT(y))                  [S3]
//     c_tilde, c = Challenge(w, mu)              [S4]
//     z, reject_z = z=y+c*s1 + normitarkistus   [S5]
//     if reject_z: kappa+=L; continue
//     h, reject_h = MakeHint+normitarkistukset  [S6]
//     if reject_h: kappa+=L; continue
//     done - z, h, c_tilde ovat lopullinen (PAKKAAMATON) allekirjoitus
//
// TAMA MODUULI EI VIELA PAKKAA allekirjoitusta (S8, seuraava vaihe) -
// ulostulo on z (etumerkillisena), h (tiheana 0/1-taulukkona) ja
// c_tilde, valmiina S8:n omalle pakkaukselle.

`timescale 1ns/1ps

module pqc_dilithium_sign_top #(
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
    input  logic [L*256*CW-1:0] s1_in_flat,   // Zq-edustajina
    input  logic [K*256*CW-1:0] s2_in_flat,   // Zq-edustajina
    input  logic [K*256*CW-1:0] t0_in_flat,   // Zq-edustajina
    input  logic [8*MSG_BYTES-1:0] m_in,
    input  logic [255:0] rnd_in,

    output logic done,
    output logic [L*256*ZW-1:0] z_out_flat,   // etumerkillinen
    output logic [K*256-1:0] h_out_flat,       // tiheana 0/1
    output logic [383:0] c_tilde_out,
    output logic [15:0] kappa_final_out,       // debug: monesko kierros onnistui
    output logic [7:0] iter_count_out           // debug: kierrosten maara
);

  // --- mu = H(tr||m,64) ---
  logic mu_start, mu_done;
  logic [8*136-1:0] mu_msg_in;
  logic [511:0] mu_out;
  pqc_shake256 #(.MAX_BLOCKS(1), .MAX_OUT_BYTES(64)) mu_dut (
    .clk(clk), .reset(reset), .start(mu_start),
    .msg_in(mu_msg_in), .msg_len_bytes(16'(64+MSG_BYTES)), .out_len_bytes(16'd64),
    .out_data(mu_out), .done(mu_done)
  );

  // --- rho_prime = H(K||rnd||mu,64) ---
  logic rp_start, rp_done;
  logic [8*136-1:0] rp_msg_in;
  logic [511:0] rp_out;
  pqc_shake256 #(.MAX_BLOCKS(1), .MAX_OUT_BYTES(64)) rp_dut (
    .clk(clk), .reset(reset), .start(rp_start),
    .msg_in(rp_msg_in), .msg_len_bytes(16'd96), .out_len_bytes(16'd64),
    .out_data(rp_out), .done(rp_done)
  );

  // --- A_hat = ExpandA(rho), KERRAN ---
  logic expA_start, expA_done;
  logic [K*L*256*CW-1:0] A_hat;
  pqc_dilithium_expand_a #(.Q(Q), .CW(CW), .K(K), .L(L)) expA_dut (
    .clk(clk), .reset(reset), .start(expA_start),
    .rho_in(rho_in), .done(expA_done), .A_out_flat(A_hat)
  );

  // --- y = ExpandMask(rho_prime, kappa) ---
  logic em_start, em_done;
  logic [15:0] kappa_reg;
  logic [L*256*ZW-1:0] y_flat;
  pqc_dilithium_expand_mask_vector #(.GAMMA1(GAMMA1), .ZW(ZW), .L(L)) em_dut (
    .clk(clk), .reset(reset), .start(em_start),
    .rho_prime_in(rp_out), .kappa_in(kappa_reg),
    .done(em_done), .y_out_flat(y_flat)
  );

  // --- y:n etumerkillinen -> Zq-muunnos (rekisteroity, valttaen
  // pitkan kombinatorisen ketjun - sama opetus kuin Verify-tyossa) ---
  logic [L*256*ZW-1:0] y_flat_reg;
  logic [L*256*CW-1:0] y_zq;
  genvar gyi, gyj;
  generate
    for (gyi = 0; gyi < L; gyi++) begin : g_y_row
      for (gyj = 0; gyj < 256; gyj++) begin : g_y_coeff
        wire signed [ZW-1:0] raw = y_flat_reg[(gyi*256+gyj)*ZW +: ZW];
        assign y_zq[(gyi*256+gyj)*CW +: CW] = (raw < 0) ? (Q + raw) : raw[CW-1:0];
      end
    end
  endgenerate

  // --- w = NTT^-1(A_hat@NTT(y)) ---
  logic w_start, w_done;
  logic [K*256*CW-1:0] w_flat;
  logic [K*256*CW-1:0] w_flat_reg;  // rekisteroity - katkaisee pitkan kombinatorisen ketjun moduulirajan yli
  pqc_dilithium_sign_w_core #(.Q(Q), .CW(CW), .K(K), .L(L)) w_dut (
    .clk(clk), .reset(reset), .start(w_start),
    .A_hat_in(A_hat), .y_in_flat(y_zq),
    .done(w_done), .w_out_flat(w_flat)
  );

  // --- Challenge ---
  logic ch_start, ch_done;
  logic [383:0] c_tilde_reg;
  logic [256*8-1:0] c_flat;
  pqc_dilithium_sign_challenge #(.Q(Q), .CW(CW), .K(K), .TAU(TAU)) ch_dut (
    .clk(clk), .reset(reset), .start(ch_start),
    .w_in_flat(w_flat_reg), .mu_in(mu_out),
    .done(ch_done), .c_tilde_out(c_tilde_reg), .c_out_flat(c_flat)
  );

  // --- z + normitarkistus ---
  logic z_start, z_done, z_reject;
  logic [L*256*ZW-1:0] z_flat;
  logic [256*8-1:0] c_flat_reg;  // rekisteroity - katkaisee pitkan kombinatorisen ketjun (sama opetus kuin Verify-tyossa)
  pqc_dilithium_sign_z_core #(.Q(Q), .CW(CW), .L(L), .GAMMA1(GAMMA1), .BETA(BETA), .ZW(ZW)) z_dut (
    .clk(clk), .reset(reset), .start(z_start),
    .s1_in_flat(s1_in_flat), .y_in_flat(y_flat_reg), .c_in_flat(c_flat_reg),
    .done(z_done), .z_out_flat(z_flat), .reject(z_reject)
  );

  // --- Hintien muodostus ---
  logic h_start, h_done, h_reject;
  logic [K*256-1:0] h_flat;
  pqc_dilithium_sign_hint_core #(.Q(Q), .CW(CW), .K(K)) h_dut (
    .clk(clk), .reset(reset), .start(h_start),
    .w_in_flat(w_flat_reg), .s2_in_flat(s2_in_flat), .t0_in_flat(t0_in_flat), .c_in_flat(c_flat_reg),
    .done(h_done), .h_out_flat(h_flat), .reject(h_reject)
  );

  typedef enum logic [4:0] {
    S_IDLE,
    S_START_MU, S_WAIT_MU,
    S_START_RP, S_WAIT_RP,
    S_START_A, S_WAIT_A,
    S_LOOP_START_EM, S_LOOP_WAIT_EM, S_LOOP_STORE_EM,
    S_LOOP_START_W, S_LOOP_WAIT_W,
    S_LOOP_START_CH, S_LOOP_WAIT_CH,
    S_LOOP_START_Z, S_LOOP_WAIT_Z,
    S_LOOP_CHECK_Z,
    S_LOOP_START_H, S_LOOP_WAIT_H,
    S_LOOP_CHECK_H,
    S_DONE
  } state_e;
  state_e state;

  logic [7:0] iter_ctr;

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
          rp_msg_in <= '0;
          rp_msg_in[255:0] <= k_key_in;
          rp_msg_in[511:256] <= rnd_in;
          rp_msg_in[1023:512] <= mu_out;
          state <= S_START_RP;
        end

        S_START_RP: begin rp_start <= 1'b1; state <= S_WAIT_RP; end
        S_WAIT_RP: if (rp_done) state <= S_START_A;

        S_START_A: begin expA_start <= 1'b1; state <= S_WAIT_A; end
        S_WAIT_A: if (expA_done) begin
          kappa_reg <= 16'd0;
          iter_ctr <= 8'd0;
          state <= S_LOOP_START_EM;
        end

        S_LOOP_START_EM: begin em_start <= 1'b1; state <= S_LOOP_WAIT_EM; end
        S_LOOP_WAIT_EM: if (em_done) state <= S_LOOP_STORE_EM;
        S_LOOP_STORE_EM: begin
          y_flat_reg <= y_flat;
          state <= S_LOOP_START_W;
        end

        S_LOOP_START_W: begin w_start <= 1'b1; state <= S_LOOP_WAIT_W; end
        S_LOOP_WAIT_W: if (w_done) begin
          w_flat_reg <= w_flat;
          state <= S_LOOP_START_CH;
        end

        S_LOOP_START_CH: begin ch_start <= 1'b1; state <= S_LOOP_WAIT_CH; end
        S_LOOP_WAIT_CH: if (ch_done) begin
          c_flat_reg <= c_flat;
          state <= S_LOOP_START_Z;
        end

        S_LOOP_START_Z: begin z_start <= 1'b1; state <= S_LOOP_WAIT_Z; end
        S_LOOP_WAIT_Z: if (z_done) state <= S_LOOP_CHECK_Z;

        S_LOOP_CHECK_Z: begin
          if (z_reject) begin
            kappa_reg <= kappa_reg + L[15:0];
            iter_ctr <= iter_ctr + 8'd1;
            state <= S_LOOP_START_EM;
          end else begin
            state <= S_LOOP_START_H;
          end
        end

        S_LOOP_START_H: begin h_start <= 1'b1; state <= S_LOOP_WAIT_H; end
        S_LOOP_WAIT_H: if (h_done) state <= S_LOOP_CHECK_H;

        S_LOOP_CHECK_H: begin
          if (h_reject) begin
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

  assign z_out_flat = z_flat;
  assign h_out_flat = h_flat;
  assign c_tilde_out = c_tilde_reg;
  assign kappa_final_out = kappa_reg;
  assign iter_count_out = iter_ctr;

endmodule
