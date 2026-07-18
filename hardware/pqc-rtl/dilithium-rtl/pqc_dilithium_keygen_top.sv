// pqc_dilithium_keygen_top.sv
//
// M5-DILITHIUM-001: KOKO ML-DSA-65.KeyGen_internal (FIPS 204
// Algoritmi 6). Yhdistaa KAIKKI nelja DK-rakennuspalikkaa (DK1 NTT,
// DK2 ExpandA, DK3 ExpandS, DK4 t-laskenta+Power2Round+pakkaus)
// yhdeksi taydeksi orkestroinniksi.
//
// Sekvenssi:
// 1. seed_domain_sep = zeta(32) || K(=6,1 tavu) || L(=5,1 tavu), 34 tavua
// 2. seed_bytes = SHAKE256(seed_domain_sep, 128 tavua)
// 3. rho=seed_bytes[0:32], rho_prime=seed_bytes[32:96], K_key=seed_bytes[96:128]
// 4. A_hat = ExpandA(rho)
// 5. s1,s2 = ExpandS(rho_prime)
// 6. t = NTT^-1(A_hat @ NTT(s1)) + s2
// 7. t1,t0 = Power2Round(t)
// 8. ek = pack_ek(rho,t1)
// 9. dk = pack_dk(rho,K_key,ek,pack_s(s1),pack_s(s2),pack_t0(t0))

`timescale 1ns/1ps

module pqc_dilithium_keygen_top #(
    parameter int Q = 8380417,
    parameter int CW = 23,
    parameter int K = 6,
    parameter int L = 5,
    parameter int ETA = 4,
    parameter int D = 13
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [255:0] zeta_in,

    output logic done,
    output logic [8*(32+K*320)-1:0] ek_out,
    output logic [8*(32+32+64+L*128+K*128+K*416)-1:0] dk_out
);

  // --- Vaihe 1-3: siemenen johtaminen SHAKE256:lla ---
  logic seed_shake_start, seed_shake_done;
  logic [8*136-1:0] seed_shake_msg_in;
  logic [8*128-1:0] seed_shake_out;
  pqc_shake256 #(.MAX_BLOCKS(1), .MAX_OUT_BYTES(128)) seed_shake_dut (
    .clk(clk), .reset(reset), .start(seed_shake_start),
    .msg_in(seed_shake_msg_in), .msg_len_bytes(16'd34), .out_len_bytes(16'd128),
    .out_data(seed_shake_out), .done(seed_shake_done)
  );

  logic [255:0] rho, K_key;
  logic [511:0] rho_prime;

  // --- Vaihe 4: ExpandA ---
  logic expA_start, expA_done;
  logic [K*L*256*CW-1:0] A_hat;
  pqc_dilithium_expand_a #(.Q(Q), .CW(CW), .K(K), .L(L)) expA_dut (
    .clk(clk), .reset(reset), .start(expA_start),
    .rho_in(rho), .done(expA_done), .A_out_flat(A_hat)
  );

  // --- Vaihe 5: ExpandS ---
  logic expS_start, expS_done;
  logic [L*256*8-1:0] s1_flat;
  logic [K*256*8-1:0] s2_flat;
  pqc_dilithium_expand_s #(.ETA(ETA), .K(K), .L(L)) expS_dut (
    .clk(clk), .reset(reset), .start(expS_start),
    .rho_prime_in(rho_prime), .done(expS_done),
    .s1_out_flat(s1_flat), .s2_out_flat(s2_flat)
  );

  // --- Vaihe 6: t-laskenta ---
  logic kc_start, kc_done;
  logic [K*256*CW-1:0] t_flat;
  pqc_dilithium_keygen_core #(.Q(Q), .CW(CW), .K(K), .L(L)) kc_dut (
    .clk(clk), .reset(reset), .start(kc_start),
    .A_hat_in(A_hat), .s1_in_flat(s1_flat), .s2_in_flat(s2_flat),
    .done(kc_done), .t_out_flat(t_flat)
  );

  // --- Vaihe 7: Power2Round (taysin kombinatorinen) ---
  logic [K*256*(CW-D)-1:0] t1_flat;
  logic [K*256*CW-1:0] t0_flat;
  pqc_dilithium_power2round_vector #(.Q(Q), .CW(CW), .D(D), .K(K)) p2r_dut (
    .t_in_flat(t_flat), .t1_out_flat(t1_flat), .t0_out_flat(t0_flat)
  );

  // --- Vaihe 8: ek-pakkaus (taysin kombinatorinen) ---
  pqc_dilithium_pack_ek #(.K(K)) ek_dut (
    .rho_in(rho), .t1_in_flat(t1_flat), .ek_out(ek_out)
  );

  // --- s1/s2/t0-pakkaus (taysin kombinatorinen) ---
  logic [L*8*128-1:0] s1_packed;
  logic [K*8*128-1:0] s2_packed;
  pqc_dilithium_pack_s_vector #(.ETA(ETA), .K(K), .L(L)) packs_dut (
    .s1_in_flat(s1_flat), .s2_in_flat(s2_flat),
    .s1_packed_out(s1_packed), .s2_packed_out(s2_packed)
  );

  logic [K*256*13-1:0] t0_packed;
  pqc_dilithium_pack_t0_vector #(.CW(CW), .K(K)) packt0_dut (
    .t0_in_flat(t0_flat), .t0_packed_out(t0_packed)
  );

  // --- Vaihe 9: dk-pakkaus (sisaltaa oman SHAKE256-kutsunsa tr=H(ek):lle) ---
  logic dk_start, dk_done;
  pqc_dilithium_pack_dk #(.K(K), .L(L)) dk_dut (
    .clk(clk), .reset(reset), .start(dk_start),
    .rho_in(rho), .K_in(K_key), .ek_in(ek_out),
    .s1_packed_in(s1_packed), .s2_packed_in(s2_packed), .t0_packed_in(t0_packed),
    .done(dk_done), .dk_out(dk_out)
  );

  typedef enum logic [3:0] {
    S_IDLE, S_START_SEED, S_WAIT_SEED,
    S_START_EXPAND, S_WAIT_EXPAND,
    S_START_KC, S_WAIT_KC,
    S_START_DK, S_WAIT_DK,
    S_DONE
  } state_e;
  state_e state;

  always_ff @(posedge clk) begin
    seed_shake_start <= 1'b0;
    expA_start <= 1'b0;
    expS_start <= 1'b0;
    kc_start <= 1'b0;
    dk_start <= 1'b0;
    done <= 1'b0;

    if (reset) begin
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: if (start) begin
          seed_shake_msg_in <= '0;
          seed_shake_msg_in[255:0] <= zeta_in;
          seed_shake_msg_in[263:256] <= 8'(K);
          seed_shake_msg_in[271:264] <= 8'(L);
          state <= S_START_SEED;
        end

        S_START_SEED: begin
          seed_shake_start <= 1'b1;
          state <= S_WAIT_SEED;
        end

        S_WAIT_SEED: if (seed_shake_done) begin
          rho <= seed_shake_out[255:0];
          rho_prime <= seed_shake_out[767:256];
          K_key <= seed_shake_out[1023:768];
          state <= S_START_EXPAND;
        end

        // ExpandA ja ExpandS voitaisiin ajaa rinnakkain (kayttavat eri
        // XOF-ydinta, EIVAT jaa resurssia) - taman ENSIMMAISEN version
        // yksinkertaisuuden vuoksi ajetaan SEKVENTIAALISESTI (korrektius
        // edella, optimointi myohemmin - sama periaate kuin muualla
        // taman projektin ajan).
        S_START_EXPAND: begin
          expA_start <= 1'b1;
          state <= S_WAIT_EXPAND;
        end

        S_WAIT_EXPAND: if (expA_done) begin
          expS_start <= 1'b1;
          state <= S_START_KC;  // odotetaan expS_done seuraavassa tilassa yhdessa kc:n kanssa
        end

        S_START_KC: if (expS_done) begin
          kc_start <= 1'b1;
          state <= S_WAIT_KC;
        end

        S_WAIT_KC: if (kc_done) begin
          dk_start <= 1'b1;
          state <= S_WAIT_DK;
        end

        S_WAIT_DK: if (dk_done) begin
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
