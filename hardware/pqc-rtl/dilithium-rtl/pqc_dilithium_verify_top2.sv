// pqc_dilithium_verify_top2.sv
//
// M5-DILITHIUM-001: KOKO ML-DSA-65.Verify_internal (FIPS 204
// Algoritmi 8), UUDELLEEN RAKENNETTU (aiempi verify_top.sv oli
// jaanne keskeytyneesta yrityksesta, poistettu). Rakennettu suoraan
// oman, jo todistetun pqc_dilithium_verify_core.sv:n paalle.
//
// EI VIELA validointeja (h.sum_hint()<=OMEGA, z.check_norm_bound) -
// TAMA ENSIMMAINEN VERSIO todentaa VAIN "aidon polun".
// Viestin (m) pituus KIINTEA 32 tavuun yksinkertaisuuden vuoksi.

`timescale 1ns/1ps

module pqc_dilithium_verify_top2 #(
    parameter int Q = 8380417,
    parameter int CW = 23,
    parameter int K = 6,
    parameter int L = 5,
    parameter int TAU = 49,
    parameter int D = 13,
    parameter int OMEGA = 55,
    parameter int MSG_BYTES = 32
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [8*(32+K*320)-1:0] pk_in,
    input  logic [8*(48+L*640+OMEGA+K)-1:0] sig_in,
    input  logic [8*MSG_BYTES-1:0] m_in,

    output logic done,
    output logic verify_ok
);

  // --- pk:n purku: rho + t1 (10-bittinen tiukka pakkaus -> Zq) ---
  wire [255:0] rho = pk_in[255:0];
  wire [K*256*10-1:0] t1_packed = pk_in[8*(32+K*320)-1:256];

  // KORJAUS (2026-07-19): generate-for 1536 erillisella assign-
  // lausekkeella aiheutti Icarus-spesifisen vakavan hidastuman
  // (kaytannossa jumin) kun tulos syotettiin isoon alimoduuliin
  // (verify_core). Ratkaisu: YKSI proseduraalinen for-silmukka
  // always_comb:ssa, EI generate-for. Todistettu erikseen
  // (incr7..incr13-debug-sarja).
  logic [K*256*CW-1:0] t1_zq;
  always_comb begin
    for (int ti = 0; ti < K*256; ti++) begin
      t1_zq[ti*CW +: CW] = {{(CW-10){1'b0}}, t1_packed[ti*10 +: 10]};
    end
  end

  // --- sig:n purku: c_tilde + z_packed + h_bytes ---
  wire [383:0] c_tilde = sig_in[383:0];
  wire [L*256*20-1:0] z_packed = sig_in[384+L*256*20-1:384];
  wire [8*(OMEGA+K)-1:0] h_bytes = sig_in[8*(48+L*640+OMEGA+K)-1:384+L*256*20];

  logic [L*256*24-1:0] z_wide;
  pqc_dilithium_unpack_z_vector #(.ZW(24), .L(L)) unpack_z_dut (
    .packed_in(z_packed), .z_out_flat(z_wide)
  );

  // KRIITTINEN KORJAUS (2026-07-19, laaja debug-loydos): rekisteri
  // z_wide:n JA Zq-muunnoksen valissa. Kahden generate-raskaan
  // moduulin (unpack_z_vector -> Zq-muunnos) suora, TAYSIN
  // KOMBINATORINEN ketjutus (ilman rekisteria valissa) aiheutti
  // Icarus Verilogin oman simulaattorin jumiutumisen jopa
  // triviaaleimmassa mahdollisessa testissa (todennettu eristetysti,
  // ks. debug-loydokset). Rekisterin lisays TAHAN VALIIN korjasi
  // taman TAYDELLISESTI - todennakoisesti tyokalun oma rajoitus
  // erittain leveiden (30720-bittisten), generate-lohkojen valisten
  // kombinatoristen riippuvuuksien ratkaisussa, EI suunnitteluvirhe.
  logic [L*256*24-1:0] z_wide_reg;
  always_ff @(posedge clk) begin
    if (reset) z_wide_reg <= '0;
    else if (state == S_WAIT_SIB) z_wide_reg <= z_wide;  // latchataan kerran, hyvissa ajoin ennen kayttoa
  end

  // z_wide_reg on 24-bittinen ETUMERKILLINEN - muunnetaan Zq-edustajaksi [0,Q)
  logic [L*256*CW-1:0] z_zq;
  logic signed [23:0] z_raw_tmp;
  always_comb begin
    for (int zi = 0; zi < L*256; zi++) begin
      z_raw_tmp = z_wide_reg[zi*24 +: 24];
      z_zq[zi*CW +: CW] = (z_raw_tmp < 0) ? (Q + z_raw_tmp) : z_raw_tmp[CW-1:0];
    end
  end

  // --- ExpandA ---
  logic expA_start, expA_done;
  logic [K*L*256*CW-1:0] A_hat;
  pqc_dilithium_expand_a #(.Q(Q), .CW(CW), .K(K), .L(L)) expA_dut (
    .clk(clk), .reset(reset), .start(expA_start),
    .rho_in(rho), .done(expA_done), .A_out_flat(A_hat)
  );

  // --- tr = SHAKE256(pk,64) ---
  logic tr_start, tr_done;
  logic [8*136*15-1:0] tr_msg_in;
  logic [8*64-1:0] tr_out;
  pqc_shake256 #(.MAX_BLOCKS(15), .MAX_OUT_BYTES(64)) tr_dut (
    .clk(clk), .reset(reset), .start(tr_start),
    .msg_in(tr_msg_in), .msg_len_bytes(16'd1952), .out_len_bytes(16'd64),
    .out_data(tr_out), .done(tr_done)
  );

  // --- mu = SHAKE256(tr||m,64) ---
  logic mu_start, mu_done;
  logic [8*136-1:0] mu_msg_in;
  logic [8*64-1:0] mu_out;
  pqc_shake256 #(.MAX_BLOCKS(1), .MAX_OUT_BYTES(64)) mu_dut (
    .clk(clk), .reset(reset), .start(mu_start),
    .msg_in(mu_msg_in), .msg_len_bytes(16'(64+MSG_BYTES)), .out_len_bytes(16'd64),
    .out_data(mu_out), .done(mu_done)
  );

  // --- c = SampleInBall(c_tilde,TAU) ---
  logic sib_start, sib_done, sib_exhausted;
  logic [256*8-1:0] c_flat;
  pqc_dilithium_sample_in_ball #(.TAU(TAU)) sib_dut (
    .clk(clk), .reset(reset), .start(sib_start),
    .c_tilde_in(c_tilde), .done(sib_done), .error_exhausted(sib_exhausted), .coeffs_out_flat(c_flat)
  );

  // --- unpack_h ---
  logic uh_start, uh_done;
  logic [K*256-1:0] h_dense;
  pqc_dilithium_unpack_h #(.OMEGA(OMEGA), .K(K)) unpack_h_dut (
    .clk(clk), .reset(reset), .start(uh_start),
    .h_bytes_in(h_bytes), .done(uh_done), .h_out_flat(h_dense)
  );

  // --- Verify-ydin: Az_minus_ct1 ---
  logic core_start, core_done;
  logic [K*256*CW-1:0] az_minus_ct1;
  pqc_dilithium_verify_core #(.Q(Q), .CW(CW), .K(K), .L(L), .D(D)) core_dut (
    .clk(clk), .reset(reset), .start(core_start),
    .A_hat_in(A_hat), .z_in_flat(z_zq), .t1_in_flat(t1_zq), .c_in_flat(c_flat),
    .done(core_done), .az_minus_ct1_out_flat(az_minus_ct1)
  );

  // --- UseHint jokaiselle K*256 kertoimelle (taysin rinnakkainen,
  // kombinatorinen - decompose/use_hint EIVAT tarvitse kelloa) ---
  logic [K*256*4-1:0] w_prime;
  genvar gwi, gwj;
  generate
    for (gwi = 0; gwi < K; gwi++) begin : g_w_row
      for (gwj = 0; gwj < 256; gwj++) begin : g_w_coeff
        pqc_dilithium_use_hint #(.Q(Q), .CW(CW)) uh_inst (
          .h_in(h_dense[gwi*256+gwj]),
          .r_in(az_minus_ct1[(gwi*256+gwj)*CW +: CW]),
          .result_out(w_prime[(gwi*256+gwj)*4 +: 4])
        );
      end
    end
  endgenerate

  // --- bit_pack_w ---
  logic [8*K*128-1:0] w_prime_bytes;
  pqc_dilithium_pack_w #(.K(K)) pack_w_dut (
    .w_prime_in_flat(w_prime), .w_prime_packed_out(w_prime_bytes)
  );

  // --- Lopullinen SHAKE256(mu||w_prime_bytes,48) ---
  logic final_start, final_done;
  logic [8*136*7-1:0] final_msg_in;
  logic [8*48-1:0] final_out;
  pqc_shake256 #(.MAX_BLOCKS(7), .MAX_OUT_BYTES(48)) final_dut (
    .clk(clk), .reset(reset), .start(final_start),
    .msg_in(final_msg_in), .msg_len_bytes(16'(64+K*128)), .out_len_bytes(16'd48),
    .out_data(final_out), .done(final_done)
  );

  typedef enum logic [4:0] {
    S_IDLE,
    S_START_TR, S_WAIT_TR,
    S_START_MU, S_WAIT_MU,
    S_START_A, S_WAIT_A,
    S_START_SIB, S_WAIT_SIB,
    S_START_UH, S_WAIT_UH,
    S_START_CORE, S_WAIT_CORE,
    S_START_FINAL, S_WAIT_FINAL,
    S_COMPARE, S_DONE
  } state_e;
  state_e state;

  always_ff @(posedge clk) begin
    tr_start <= 1'b0;
    mu_start <= 1'b0;
    expA_start <= 1'b0;
    sib_start <= 1'b0;
    uh_start <= 1'b0;
    core_start <= 1'b0;
    final_start <= 1'b0;
    done <= 1'b0;

    if (reset) begin
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: if (start) begin
          tr_msg_in <= '0;
          tr_msg_in[8*(32+K*320)-1:0] <= pk_in;
          state <= S_START_TR;
        end

        S_START_TR: begin
          tr_start <= 1'b1;
          state <= S_WAIT_TR;
        end
        S_WAIT_TR: if (tr_done) begin
          mu_msg_in <= '0;
          mu_msg_in[511:0] <= tr_out;
          mu_msg_in[8*(64+MSG_BYTES)-1:512] <= m_in;
          state <= S_START_MU;
        end

        S_START_MU: begin
          mu_start <= 1'b1;
          state <= S_WAIT_MU;
        end
        S_WAIT_MU: if (mu_done) state <= S_START_A;

        S_START_A: begin
          expA_start <= 1'b1;
          state <= S_WAIT_A;
        end
        S_WAIT_A: if (expA_done) state <= S_START_SIB;

        S_START_SIB: begin
          sib_start <= 1'b1;
          state <= S_WAIT_SIB;
        end
        S_WAIT_SIB: if (sib_done) state <= S_START_UH;

        S_START_UH: begin
          uh_start <= 1'b1;
          state <= S_WAIT_UH;
        end
        S_WAIT_UH: if (uh_done) state <= S_START_CORE;

        S_START_CORE: begin
          core_start <= 1'b1;
          state <= S_WAIT_CORE;
        end
        S_WAIT_CORE: if (core_done) begin
          final_msg_in <= '0;
          final_msg_in[511:0] <= mu_out;
          final_msg_in[8*(64+K*128)-1:512] <= w_prime_bytes;
          state <= S_START_FINAL;
        end

        S_START_FINAL: begin
          final_start <= 1'b1;
          state <= S_WAIT_FINAL;
        end
        S_WAIT_FINAL: if (final_done) state <= S_COMPARE;

        S_COMPARE: begin
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

  assign verify_ok = (c_tilde[383:0] === final_out[383:0]);

endmodule
