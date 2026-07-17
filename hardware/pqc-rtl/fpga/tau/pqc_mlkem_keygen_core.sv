// pqc_mlkem_keygen_core.sv
//
// M4-TAU-001 Osa 5 (M4-MLKEM-ORCH-001): ENSIMMAINEN synteesikelpoinen
// ML-KEM.KeyGen_internal-orkestrointimoduuli (FIPS 203 Algoritmi 16).
//
// TARKEA LOYDOS (2026-07-19): koko ML-KEM.KeyGen/Encaps/Decaps on
// tahan asti ollut olemassa VAIN testipenkkien proseduraalisena
// orkestrointina (initial-lohkot, ei-synteesikelpoiset rakenteet) -
// jokainen ALIMODUULI on synteesikelpoinen ja todistettu, mutta
// niita YHDISTAVA ohjauslogiikka ei ole. Tama moduuli on ENSIMMAINEN
// askel taman aukon korjaamiseksi: synteesikelpoinen tilakone joka
// ajaa TASMALLEEN saman sekvenssin kuin pqc_mlkem_keygen_tb.sv,
// mutta synteesikelpoisena RTL:na (ei testipenkin omana proseduraalisena
// koodina).
//
// SEKVENSSI (K=2, ML-KEM-512):
// 1. SHA3-512(d||K) -> rho, sigma
// 2. SampleNTT(rho,i,j) x4 (KxK) -> A[i][j]
// 3. PRF+SamplePolyCBD(sigma,N) x4 (2K) -> s_vec[i], e_vec[i]
// 4. NTT-forward x4 (2K) -> s_hat[i], e_hat[i]
// 5. Matriisikertolasku+summaus: t_hat[i] = sum_j(A[i][j]*s_hat[j]) + e_hat[i]
// 6. ByteEncode12(t_hat) + rho -> ek
// 7. ByteEncode12(s_hat) -> dkPKE
// 8. H(ek)=SHA3-256(ek), kokoa dk = dkPKE||ek||H(ek)||z
//
// TAMA ON TUTKIMUSPROTOTYYPPI (fpga/tau/) - EI VIELA tuotanto-
// integraatiota. Testattu Icarus Verilogilla, EI VIELA synteesi-
// testattu ECP5:lla.

`timescale 1ns/1ps

module pqc_mlkem_keygen_core #(
    parameter int COEFF_W = 16,
    parameter int SPAD_AW = 9,
    parameter int K = 2,
    parameter int ETA1 = 3
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [255:0] d_seed,
    input  logic [255:0] z_seed,

    output logic done,
    output logic [8*800-1:0] ek_out,
    output logic [8*1632-1:0] dk_out,

    // TILAPAINEN debug-ulostulo taman osittaisen version testausta
    // varten - poistetaan kun koko sekvenssi on valmis.
    output logic [255:0] debug_rho,
    output logic [255:0] debug_sigma,
    output logic [256*COEFF_W-1:0] debug_A00,
    output logic [4:0] debug_state
);

  // --- Alimoduulit (kaikki jo todennettuja, uudelleenkaytettyja) ---
  logic ntt_start, stage_done, bank_conflict_detected;
  logic [7:0] ntt_count, ntt_pair_dist;
  logic ntt_mode;
  logic [SPAD_AW-1:0] base_addr_lane0, base_addr_lane1;
  logic [COEFF_W-1:0] zeta_lane0, zeta_lane1;
  logic ntt_load_valid, ntt_read_en, ntt_read_valid;
  logic [7:0] ntt_load_addr, ntt_read_addr;
  logic [COEFF_W-1:0] ntt_load_data, ntt_read_data;

  pqc_ntt_stage_banked #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW), .FPGA_BRINGUP(1)) ntt_dut (
    .clk(clk), .reset(reset), .start(ntt_start), .count(ntt_count),
    .pair_dist(ntt_pair_dist), .mode(ntt_mode),
    .base_addr_lane0(base_addr_lane0), .base_addr_lane1(base_addr_lane1),
    .zeta_lane0(zeta_lane0), .zeta_lane1(zeta_lane1),
    .stage_done(stage_done), .bank_conflict_detected(bank_conflict_detected),
    .load_valid(ntt_load_valid), .load_addr(ntt_load_addr), .load_data(ntt_load_data),
    .read_en(ntt_read_en), .read_addr(ntt_read_addr), .read_valid(ntt_read_valid), .read_data(ntt_read_data)
  );

  // --- NTT-aikataulun ROM (M4-MLKEM-ORCH-001): 64 merkintaa (taso 6
  // + full_schedule.txt), pakattu 64-bittisiksi sanoiksi:
  // {length[8], base0[9], zeta0[16], base1[9], zeta1[16]} ---
  logic [63:0] ntt_schedule_rom [0:63];
  initial begin
    $readmemh("fpga/tau/mlkem_ntt_schedule_rom.memh", ntt_schedule_rom);
  end

  logic sha512_start, sha512_done;
  logic [8*72-1:0] sha512_msg_in;
  logic [511:0] sha512_out;
  pqc_sha3_512 #(.MAX_BLOCKS(1)) sha512_dut (
    .clk(clk), .reset(reset), .start(sha512_start),
    .msg_in(sha512_msg_in), .msg_len_bytes(16'd33),
    .digest_out(sha512_out), .done(sha512_done)
  );

  logic sha256_start, sha256_done;
  logic [8*136*6-1:0] sha256_msg_in;
  logic [255:0] sha256_out;
  pqc_sha3_256 #(.MAX_BLOCKS(6)) sha256_dut (
    .clk(clk), .reset(reset), .start(sha256_start),
    .msg_in(sha256_msg_in), .msg_len_bytes(16'd800),
    .digest_out(sha256_out), .done(sha256_done)
  );

  logic samplentt_start, samplentt_done, samplentt_err;
  logic [255:0] samplentt_rho;
  logic [7:0] samplentt_j, samplentt_i;
  logic [256*COEFF_W-1:0] samplentt_out;
  logic [15:0] sn_acc, sn_rej, sn_xof;
  pqc_samplentt #(.XOF_BYTES(1008)) samplentt_dut (
    .clk(clk), .reset(reset), .start(samplentt_start),
    .rho(samplentt_rho), .byte_j(samplentt_j), .byte_i(samplentt_i),
    .a_hat(samplentt_out), .accepted_count(sn_acc), .rejected_count(sn_rej),
    .xof_bytes_consumed(sn_xof), .done(samplentt_done), .error_exhausted(samplentt_err)
  );

  logic cbd1_start, cbd1_done;
  logic [255:0] cbd1_seed;
  logic [7:0] cbd1_n;
  logic [256*COEFF_W-1:0] cbd1_out;
  pqc_prf_samplepolycbd #(.ETA(ETA1)) cbd1_dut (
    .clk(clk), .reset(reset), .start(cbd1_start),
    .seed_s(cbd1_seed), .counter_n(cbd1_n), .f_out(cbd1_out), .done(cbd1_done)
  );

  logic [256*COEFF_W-1:0] mntt_f, mntt_g, mntt_h;
  pqc_multiplyntts #(.COEFF_W(COEFF_W)) mntt_dut (.f_hat(mntt_f), .g_hat(mntt_g), .h_hat(mntt_h));

  logic [256*COEFF_W-1:0] padd_a, padd_b, padd_sum;
  pqc_polyadd #(.COEFF_W(COEFF_W)) padd_dut (.a_in(padd_a), .b_in(padd_b), .sum_out(padd_sum));

  logic [256*12-1:0] benc12_in [0:1];
  logic [8*384-1:0] benc12_out [0:1];
  pqc_byteencode_dparam #(.D(12)) benc12_0 (.f_in(benc12_in[0]), .b_out(benc12_out[0]));
  pqc_byteencode_dparam #(.D(12)) benc12_1 (.f_in(benc12_in[1]), .b_out(benc12_out[1]));

  // --- Tallennusrekisterit (K=2-kokoiset taulukot) ---
  logic [255:0] rho, sigma;
  logic [256*COEFF_W-1:0] A [0:K-1][0:K-1];
  logic [256*COEFF_W-1:0] s_vec [0:K-1], e_vec [0:K-1];
  logic [256*COEFF_W-1:0] s_hat [0:K-1], e_hat [0:K-1], t_hat [0:K-1];
  logic [255:0] H_ek;
  logic [8*800-1:0] ek_reg;
  logic [8*1632-1:0] dk_reg;

  // --- Paatilakone: askellaskuri, joka kayy lapi tasmalleen saman
  // sekvenssin kuin testipenkin oma initial-lohko. ---
  typedef enum logic [4:0] {
    S_IDLE, S_RESET_SHA512, S_START_SHA512, S_WAIT_SHA512,
    S_RESET_SNTT, S_START_SNTT, S_WAIT_SNTT, S_SNTT_NEXT,
    S_RESET_CBD, S_START_CBD, S_WAIT_CBD, S_CBD_NEXT,
    S_NTT_FWD_LOAD, S_NTT_FWD_SCHED_START, S_NTT_FWD_SCHED_WAIT,
    S_NTT_FWD_READ, S_NTT_FWD_READ_WAIT, S_NTT_FWD_NEXT,
    S_MATMUL, S_MATMUL_NEXT,
    S_ENCODE_T, S_ENCODE_S,
    S_RESET_SHA256, S_START_SHA256, S_WAIT_SHA256,
    S_ASSEMBLE, S_DONE
  } state_e;
  state_e state, return_state;

  logic [1:0] i_ctr, j_ctr;
  logic [1:0] n_ctr;
  logic [1:0] fwd_ctr;
  logic [1:0] mm_i, mm_j;
  logic [256*COEFF_W-1:0] mm_acc;
  logic [7:0] load_idx, read_idx;
  logic [5:0] sched_idx;
  logic [256*COEFF_W-1:0] fwd_poly_in, fwd_poly_out;

  always_ff @(posedge clk) begin
    ntt_start <= 1'b0;
    sha512_start <= 1'b0;
    sha256_start <= 1'b0;
    samplentt_start <= 1'b0;
    cbd1_start <= 1'b0;
    done <= 1'b0;

    if (reset) begin
      state <= S_IDLE;
      i_ctr <= 2'd0; j_ctr <= 2'd0; n_ctr <= 2'd0;
    end else begin
      case (state)
        S_IDLE: begin
          if (start) begin
            sha512_msg_in <= '0;
            sha512_msg_in[255:0] <= d_seed;
            sha512_msg_in[263:256] <= K[7:0];
            state <= S_START_SHA512;
          end
        end

        S_START_SHA512: begin
          sha512_start <= 1'b1;
          state <= S_WAIT_SHA512;
        end
        S_WAIT_SHA512: begin
          if (sha512_done) begin
            rho   <= sha512_out[255:0];
            sigma <= sha512_out[511:256];
            i_ctr <= 2'd0; j_ctr <= 2'd0;
            state <= S_START_SNTT;
          end
        end

        // --- SampleNTT KxK kertaa ---
        S_START_SNTT: begin
          samplentt_rho <= rho; samplentt_i <= {6'b0,i_ctr}; samplentt_j <= {6'b0,j_ctr};
          samplentt_start <= 1'b1;
          state <= S_WAIT_SNTT;
        end
        S_WAIT_SNTT: begin
          if (samplentt_done) begin
            A[i_ctr][j_ctr] <= samplentt_out;
            state <= S_SNTT_NEXT;
          end
        end
        S_SNTT_NEXT: begin
          if (j_ctr == K-1) begin
            j_ctr <= 2'd0;
            if (i_ctr == K-1) begin
              i_ctr <= 2'd0; n_ctr <= 2'd0;
              state <= S_START_CBD;
            end else begin
              i_ctr <= i_ctr + 2'd1;
              state <= S_START_SNTT;
            end
          end else begin
            j_ctr <= j_ctr + 2'd1;
            state <= S_START_SNTT;
          end
        end

        // --- PRF+SamplePolyCBD 2K kertaa: ensin K s_vec, sitten K e_vec ---
        S_START_CBD: begin
          cbd1_seed <= sigma; cbd1_n <= {6'b0,n_ctr};
          cbd1_start <= 1'b1;
          state <= S_WAIT_CBD;
        end
        S_WAIT_CBD: begin
          if (cbd1_done) begin
            if (n_ctr < K) s_vec[n_ctr[0]] <= cbd1_out;
            else e_vec[n_ctr[0]] <= cbd1_out;
            state <= S_CBD_NEXT;
          end
        end
        S_CBD_NEXT: begin
          if (n_ctr == 2*K-1) begin
            fwd_ctr <= 2'd0;
            load_idx <= 8'd0;
            fwd_poly_in <= s_vec[0];
            state <= S_NTT_FWD_LOAD;
          end else begin
            n_ctr <= n_ctr + 2'd1;
            state <= S_START_CBD;
          end
        end

        // --- NTT-forward: 4 kertaa (s_vec[0], s_vec[1], e_vec[0],
        // e_vec[1]) -> s_hat[0], s_hat[1], e_hat[0], e_hat[1].
        // Kayttaa ytimen omaa FPGA_BRINGUP-rajapintaa (load_valid/
        // load_addr/load_data, read_en/read_addr/read_valid/
        // read_data) - EI hierarkkista suoraa kirjoitusta (joka EI
        // ole synteesikelpoinen). ---
        S_NTT_FWD_LOAD: begin
          ntt_load_valid <= 1'b1;
          ntt_load_addr  <= load_idx;
          ntt_load_data  <= fwd_poly_in[load_idx*COEFF_W +: COEFF_W];
          if (load_idx == 8'd255) begin
            sched_idx <= 6'd0;
            state <= S_NTT_FWD_SCHED_START;
          end else begin
            load_idx <= load_idx + 8'd1;
          end
        end

        S_NTT_FWD_SCHED_START: begin
          ntt_load_valid <= 1'b0;
          begin
            logic [63:0] entry;
            entry = ntt_schedule_rom[sched_idx];
            ntt_pair_dist   <= entry[57:50];
            base_addr_lane0 <= entry[49:41];
            zeta_lane0      <= entry[40:25];
            base_addr_lane1 <= entry[24:16];
            zeta_lane1      <= entry[15:0];
            ntt_count       <= entry[57:50];
          end
          ntt_mode  <= 1'b0;
          ntt_start <= 1'b1;
          state <= S_NTT_FWD_SCHED_WAIT;
        end

        S_NTT_FWD_SCHED_WAIT: begin
          if (stage_done) begin
            if (sched_idx == 6'd63) begin
              read_idx <= 8'd0;
              state <= S_NTT_FWD_READ;
            end else begin
              sched_idx <= sched_idx + 6'd1;
              state <= S_NTT_FWD_SCHED_START;
            end
          end
        end

        S_NTT_FWD_READ: begin
          // Esita osoite (read_idx), odota YKSI sykli ennen luvun
          // tarkistusta - vastaa tasmalleen jo toimivaksi todistettua
          // Wishbone-lukupolkua (yksi pyynto kerrallaan, ei
          // perakkaisia paallekkaisia lukuja).
          state <= S_NTT_FWD_READ_WAIT;
        end

        S_NTT_FWD_READ_WAIT: begin
          if (ntt_read_valid) begin
            case (fwd_ctr)
              2'd0: s_hat[0][read_idx*COEFF_W +: COEFF_W] <= ntt_read_data;
              2'd1: s_hat[1][read_idx*COEFF_W +: COEFF_W] <= ntt_read_data;
              2'd2: e_hat[0][read_idx*COEFF_W +: COEFF_W] <= ntt_read_data;
              default: e_hat[1][read_idx*COEFF_W +: COEFF_W] <= ntt_read_data;
            endcase
            if (read_idx == 8'd255) begin
              state <= S_NTT_FWD_NEXT;
            end else begin
              read_idx <= read_idx + 8'd1;
              state <= S_NTT_FWD_READ;
            end
          end
        end

        S_NTT_FWD_NEXT: begin
          if (fwd_ctr == 2'd3) begin
            mm_i <= 2'd0; mm_j <= 2'd0;
            mm_acc <= '0;
            state <= S_DONE;  // TILAPAINEN - matriisikertolasku jne. seuraavaksi
          end else begin
            fwd_ctr <= fwd_ctr + 2'd1;
            load_idx <= 8'd0;
            case (fwd_ctr + 2'd1)
              2'd1: fwd_poly_in <= s_vec[1];
              2'd2: fwd_poly_in <= e_vec[0];
              default: fwd_poly_in <= e_vec[1];
            endcase
            state <= S_NTT_FWD_LOAD;
          end
        end

        default: state <= S_IDLE;
      endcase
    end
  end

  // M4-MLKEM-ORCH-001 debug-korjaus (2026-07-19): read_en/read_addr
  // TAYTYY olla KOMBINATORISIA (ei rekisteroityja) - sama periaate
  // kuin jo toimivaksi todistetussa Wishbone-lukupolussa
  // (pqc_ntt_wishbone_wrapper.sv: "assign read_en = ...", EI
  // rekisteroity <=). Ytimen oma read_valid/read_data tulevat YHDEN
  // SYKLIN viiveella - read_idx_captured tallentaa MIKA read_idx oli
  // silloin kun VASTAAVA data lopulta saapuu.
  assign ntt_read_en   = (state == S_NTT_FWD_READ) || (state == S_NTT_FWD_READ_WAIT);
  assign ntt_read_addr = read_idx;

  assign debug_rho = rho;
  assign debug_sigma = sigma;
  assign debug_A00 = A[0][0];
  assign debug_state = state;

endmodule
