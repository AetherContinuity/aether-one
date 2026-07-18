// pqc_mlkem_encaps_top.sv
//
// M4-ENCAPS-ORCH-001: ML-KEM.Encaps_internal (FIPS 203 Algoritmi 17).
//
// SEKVENSSI:
// 1. H(ek) = SHA3-256(ek, 800 tavua)
// 2. (K,r) = G(m||H(ek)) = SHA3-512
// 3. c = K-PKE.Encrypt(ek, m, r) - UUDELLEENKAYTTAA SUORAAN
//    pqc_mlkem_decaps_b1_core.sv:n jo todistetun K-PKE.Encrypt-
//    logiikan (Phase B1-B3), koska Decaps Phase B JA Encaps
//    kayttavat TASMALLEEN samaa K-PKE.Encrypt-algoritmia.
//
// Uudelleenkaytettaessa decaps_b1_core:a: c_in/z_in/K_prime_in-
// portit (jotka liittyvat VAIN Decapsin omaan FO-valintaan, Phase
// B4:aan) syotetaan nollilla - EI vaikuta c_prime_out:n omaan
// laskentaan, koska FO-valinta on VIIMEINEN, ERILLINEN vaihe joka
// EI muokkaa c':n omaa arvoa, vain PAATTAA mika K palautetaan.
// Tama moduuli EI kayta match_out/K_final_out-ulostuloja lainkaan -
// oma K palautetaan SUORAAN G-vaiheen omasta tuloksesta.

`timescale 1ns/1ps

module pqc_mlkem_encaps_top #(
    parameter int COEFF_W = 16,
    parameter int K = 2
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [8*800-1:0] ek_in,
    input  logic [255:0] m_in,

    output logic done,
    output logic [255:0] K_out,
    output logic [8*768-1:0] c_out
);

  logic sha256_start, sha256_done;
  logic [8*136*6-1:0] sha256_msg_in;
  logic [255:0] sha256_out;
  pqc_sha3_256 #(.MAX_BLOCKS(6)) sha256_dut (
    .clk(clk), .reset(reset), .start(sha256_start),
    .msg_in(sha256_msg_in), .msg_len_bytes(16'd800),
    .digest_out(sha256_out), .done(sha256_done)
  );

  logic sha512_start, sha512_done;
  logic [8*72-1:0] sha512_msg_in;
  logic [511:0] sha512_out;
  pqc_sha3_512 #(.MAX_BLOCKS(1)) sha512_dut (
    .clk(clk), .reset(reset), .start(sha512_start),
    .msg_in(sha512_msg_in), .msg_len_bytes(16'd64),
    .digest_out(sha512_out), .done(sha512_done)
  );

  // --- K-PKE.Encrypt: uudelleenkaytetty decaps_b1_core, Phase B4:n
  // (FO-valinta) omat syotteet (c_in/z_in/K_prime_in) nollattuina -
  // NAMA EIVAT vaikuta c_prime_out:n omaan laskentaan. ---
  logic encrypt_start, encrypt_done;
  logic [255:0] r_val, K_val;
  logic [8*768-1:0] c_prime;
  logic unused_match;
  logic [255:0] unused_K_final;
  logic [4*256*COEFF_W-1:0] unused_A;
  logic [K*256*COEFF_W-1:0] unused_yvec, unused_yhat, unused_e1vec, unused_uacc, unused_uvec;
  logic [256*COEFF_W-1:0] unused_e2, unused_vacc, unused_vpoly;

  pqc_mlkem_decaps_b1_core #(.COEFF_W(COEFF_W), .K(K)) kpke_encrypt (
    .clk(clk), .reset(reset), .start(encrypt_start),
    .ek_in(ek_in), .r_prime_in(r_val), .m_prime_in(m_in),
    .c_in('0), .z_in('0), .K_prime_in('0),
    .done(encrypt_done),
    .A_out_flat(unused_A), .y_vec_out_flat(unused_yvec), .y_hat_out_flat(unused_yhat),
    .e1_vec_out_flat(unused_e1vec), .e2_poly_out(unused_e2),
    .u_acc_out_flat(unused_uacc), .v_acc_out(unused_vacc),
    .u_vec_out_flat(unused_uvec), .v_poly_out(unused_vpoly),
    .c_prime_out(c_prime),
    .match_out(unused_match), .K_final_out(unused_K_final)
  );

  typedef enum logic [2:0] {
    S_IDLE, S_START_H, S_WAIT_H, S_START_G, S_WAIT_G, S_START_ENC, S_WAIT_ENC, S_DONE
  } state_e;
  state_e state;

  always_ff @(posedge clk) begin
    sha256_start <= 1'b0;
    sha512_start <= 1'b0;
    encrypt_start <= 1'b0;
    done <= 1'b0;

    if (reset) begin
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: if (start) begin
          sha256_msg_in <= '0;
          sha256_msg_in[8*800-1:0] <= ek_in;
          state <= S_START_H;
        end

        S_START_H: begin
          sha256_start <= 1'b1;
          state <= S_WAIT_H;
        end

        S_WAIT_H: if (sha256_done) begin
          sha512_msg_in[255:0] <= m_in;
          sha512_msg_in[511:256] <= sha256_out;
          state <= S_START_G;
        end

        S_START_G: begin
          sha512_start <= 1'b1;
          state <= S_WAIT_G;
        end

        S_WAIT_G: if (sha512_done) begin
          K_val <= sha512_out[255:0];
          r_val <= sha512_out[511:256];
          state <= S_START_ENC;
        end

        S_START_ENC: begin
          encrypt_start <= 1'b1;
          state <= S_WAIT_ENC;
        end

        S_WAIT_ENC: if (encrypt_done) begin
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

  assign K_out = K_val;
  assign c_out = c_prime;

endmodule
