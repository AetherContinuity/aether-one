// pqc_mlkem_decaps_b1_core.sv
//
// M4-DECAPS-ORCH-001 Phase B1: K-PKE.Encrypt:n alkuosa - A-matriisin
// muodostus (SampleNTT) ja deterministinen kohinageneraatio
// (PRF+SamplePolyCBD) r':sta. EI VIELA matriisikertolaskuja/NTT:ta -
// VAIN syotteen muodostus todennetaan tassa vaiheessa (kayttajan
// oma, tarkoituksellinen rajaus riskien hallitsemiseksi).
//
// SEKVENSSI (vastaa tb/pqc_mlkem_decaps_b_tb.sv:n alkuosaa):
// 1. ByteDecode(12) ek:sta -> t_hat[i] (EI VIELA kaytetty tassa
//    vaiheessa, mutta puretaan yhdessa rho:n kanssa koska ne
//    tulevat samasta ek-syotteesta)
// 2. rho = ek:n viimeiset 32 tavua
// 3. SampleNTT(rho,i,j) KxK kertaa -> A[i][j]
// 4. PRF+SamplePolyCBD(r',N) ETA1:lla, N=0,1 -> y_vec[0], y_vec[1]
// 5. PRF+SamplePolyCBD(r',N) ETA2:lla, N=2,3 -> e1_vec[0], e1_vec[1]
// 6. PRF+SamplePolyCBD(r',N) ETA2:lla, N=4 -> e2_poly
//
// TAMA ON TUTKIMUSPROTOTYYPPI, OSA 1/4 Phase B:sta (kayttajan oma
// B1-B4-jako). Uudelleenkayttaa M4-MLKEM-ORCH-001:n (KeyGen)
// todistettua SampleNTT+CBD-silmukkarakennetta.

`timescale 1ns/1ps

module pqc_mlkem_decaps_b1_core #(
    parameter int COEFF_W = 16,
    parameter int K = 2,
    parameter int ETA1 = 3,
    parameter int ETA2 = 2
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [8*800-1:0] ek_in,   // ek (800 tavua: K*384 t_hat + 32 rho)
    input  logic [255:0] r_prime_in,
    input  logic [255:0] m_prime_in,   // Phase A:n oma m'
    input  logic [8*768-1:0] c_in,      // alkuperainen siffertext (ECU:n oma syote)
    input  logic [255:0] z_in,           // z-siemen (dk:n oma osa)
    input  logic [255:0] K_prime_in,     // Phase G:n oma K'

    output logic done,
    output logic [4*256*COEFF_W-1:0] A_out_flat,        // A[0][0],A[0][1],A[1][0],A[1][1] jarjestyksessa
    output logic [K*256*COEFF_W-1:0] y_vec_out_flat,
    output logic [K*256*COEFF_W-1:0] y_hat_out_flat,     // B2a: NTT-forward(y_vec)
    output logic [K*256*COEFF_W-1:0] e1_vec_out_flat,
    output logic [256*COEFF_W-1:0] e2_poly_out,
    output logic [K*256*COEFF_W-1:0] u_acc_out_flat,  // B2b-1: A^T*y_hat (NTT-alueella, ennen INTT:ta)
    output logic [256*COEFF_W-1:0] v_acc_out,           // B2b-1: t_hat*y_hat (NTT-alueella, ennen INTT:ta)
    output logic [K*256*COEFF_W-1:0] u_vec_out_flat,   // B2b-2: normaalialueen u
    output logic [256*COEFF_W-1:0] v_poly_out,           // B2b-2: normaalialueen v
    output logic [8*768-1:0] c_prime_out,                  // B3: siffertext c'
    output logic match_out,                                 // B4: c == c'
    output logic [255:0] K_final_out                       // B4: lopullinen istuntoavain
);

  // --- NTT-ydin (bring-up, sama kuin KeyGenissa/Decaps A:ssa) ---
  logic ntt_start, stage_done, bank_conflict_detected;
  logic [7:0] ntt_count, ntt_pair_dist;
  logic ntt_mode;
  logic [8:0] base_addr_lane0, base_addr_lane1;
  logic [COEFF_W-1:0] zeta_lane0, zeta_lane1;
  logic ntt_load_valid, ntt_read_en, ntt_read_valid;
  logic [7:0] ntt_load_addr, ntt_read_addr;
  logic [COEFF_W-1:0] ntt_load_data, ntt_read_data;

  pqc_ntt_stage_banked #(.COEFF_W(COEFF_W), .SPAD_AW(9), .FPGA_BRINGUP(1)) ntt_dut (
    .clk(clk), .reset(reset), .start(ntt_start), .count(ntt_count),
    .pair_dist(ntt_pair_dist), .mode(ntt_mode),
    .base_addr_lane0(base_addr_lane0), .base_addr_lane1(base_addr_lane1),
    .zeta_lane0(zeta_lane0), .zeta_lane1(zeta_lane1),
    .stage_done(stage_done), .bank_conflict_detected(bank_conflict_detected),
    .load_valid(ntt_load_valid), .load_addr(ntt_load_addr), .load_data(ntt_load_data),
    .read_en(ntt_read_en), .read_addr(ntt_read_addr), .read_valid(ntt_read_valid), .read_data(ntt_read_data)
  );

  logic [71:0] fwd_schedule_rom [0:63];
  initial $readmemh("fpga/tau/mlkem_ntt_schedule_rom.memh", fwd_schedule_rom);

  logic [71:0] inv_schedule_rom [0:63];
  initial $readmemh("fpga/tau/mlkem_ntt_inverse_schedule_rom.memh", inv_schedule_rom);

  logic [256*COEFF_W-1:0] scale_in, scale_out;
  pqc_ntt_final_scale #(.COEFF_W(COEFF_W)) scale_dut (.f_in(scale_in), .f_out(scale_out));

  logic [255:0] bdec1_in, bdec1_out;

  // --- Phase B3: Compress(DU/DV) + ByteEncode(DU/DV) -> c' ---
  localparam int DU = 10;
  localparam int DV = 4;
  logic [256*COEFF_W-1:0] bcompu_in [0:1];
  logic [256*DU-1:0] bcompu_out [0:1];
  pqc_batch_compress #(.D(DU), .COEFF_W(COEFF_W)) bcompu0 (.x_packed(bcompu_in[0]), .y_packed(bcompu_out[0]));
  pqc_batch_compress #(.D(DU), .COEFF_W(COEFF_W)) bcompu1 (.x_packed(bcompu_in[1]), .y_packed(bcompu_out[1]));

  logic [256*COEFF_W-1:0] bcompv_in;
  logic [256*DV-1:0] bcompv_out;
  pqc_batch_compress #(.D(DV), .COEFF_W(COEFF_W)) bcompv (.x_packed(bcompv_in), .y_packed(bcompv_out));

  logic [256*DU-1:0] bencu_in [0:1];
  logic [256*DU-1:0] bencu_out [0:1];
  pqc_byteencode_dparam #(.D(DU)) bencu0 (.f_in(bencu_in[0]), .b_out(bencu_out[0]));
  pqc_byteencode_dparam #(.D(DU)) bencu1 (.f_in(bencu_in[1]), .b_out(bencu_out[1]));

  logic [256*DV-1:0] bencv_in, bencv_out;
  pqc_byteencode_dparam #(.D(DV)) bencv (.f_in(bencv_in), .b_out(bencv_out));

  logic [8*768-1:0] c_prime;

  logic shake256_start, shake256_done;
  logic [8*136*6-1:0] shake256_msg_in;
  logic [8*32-1:0] shake256_out;
  pqc_shake256 #(.MAX_BLOCKS(6), .MAX_OUT_BYTES(32)) shake256_dut (
    .clk(clk), .reset(reset), .start(shake256_start),
    .msg_in(shake256_msg_in), .msg_len_bytes(16'd800), .out_len_bytes(16'd32),
    .out_data(shake256_out), .done(shake256_done)
  );
  pqc_bytedecode_dparam #(.D(1)) bdec1_dut (.b_in(bdec1_in), .f_out(bdec1_out));

  logic [COEFF_W-1:0] c1_x_in, c1_y_in, c1_compress_out, c1_decompress_out;
  logic [3:0] c1_d_sel;
  pqc_compress #(.COEFF_W(COEFF_W)) compress1_dut (
    .d(c1_d_sel), .x_in(c1_x_in), .compress_out(c1_compress_out),
    .y_in(c1_y_in), .decompress_out(c1_decompress_out)
  );

  logic [256*COEFF_W-1:0] y_hat [0:K-1];
  logic [1:0] fwd_ctr;
  logic [5:0] sched_idx;
  logic [7:0] load_idx, read_idx;

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

  logic cbd2_start, cbd2_done;
  logic [255:0] cbd2_seed;
  logic [7:0] cbd2_n;
  logic [256*COEFF_W-1:0] cbd2_out;
  pqc_prf_samplepolycbd #(.ETA(ETA2)) cbd2_dut (
    .clk(clk), .reset(reset), .start(cbd2_start),
    .seed_s(cbd2_seed), .counter_n(cbd2_n), .f_out(cbd2_out), .done(cbd2_done)
  );

  logic [256*12-1:0] bdec12_in [0:1];
  logic [256*12-1:0] bdec12_out_raw [0:1];
  pqc_bytedecode_dparam #(.D(12)) bdec12_0 (.b_in(bdec12_in[0]), .f_out(bdec12_out_raw[0]));
  pqc_bytedecode_dparam #(.D(12)) bdec12_1 (.b_in(bdec12_in[1]), .f_out(bdec12_out_raw[1]));

  logic [256*COEFF_W-1:0] t_hat [0:K-1];
  logic [255:0] rho;
  logic [1:0] i_ctr, j_ctr;
  logic [2:0] n_ctr;  // 0..2K (K=2: 0,1=y_vec; 2,3=e1_vec; 4=e2_poly)

  // Sisaiset (unpacked, EI portteja - turvallinen Icarus Verilogissa)
  logic [256*COEFF_W-1:0] A [0:K-1][0:K-1];
  logic [256*COEFF_W-1:0] y_vec [0:K-1];
  logic [256*COEFF_W-1:0] e1_vec [0:K-1];

  // --- B2b-1: pisteittainen kertolasku + akkumulointi NTT-alueella ---
  logic [256*COEFF_W-1:0] mntt_f, mntt_g, mntt_h;
  pqc_multiplyntts #(.COEFF_W(COEFF_W)) mntt_dut (.f_hat(mntt_f), .g_hat(mntt_g), .h_hat(mntt_h));
  logic [256*COEFF_W-1:0] padd_a, padd_b, padd_sum;
  pqc_polyadd #(.COEFF_W(COEFF_W)) padd_dut (.a_in(padd_a), .b_in(padd_b), .sum_out(padd_sum));

  logic [256*COEFF_W-1:0] u_acc [0:K-1];  // A^T*y_hat akkumulaattori, per sarake
  logic [256*COEFF_W-1:0] v_acc;          // t_hat*y_hat akkumulaattori
  logic [1:0] mm_col, mm_j;

  typedef enum logic [5:0] {
    S_IDLE, S_DECODE_T, S_START_SNTT, S_WAIT_SNTT, S_SNTT_NEXT,
    S_START_CBD1, S_WAIT_CBD1, S_START_CBD2, S_WAIT_CBD2, S_CBD_NEXT,
    S_FWD_LOAD, S_FWD_SCHED_SETUP, S_FWD_SCHED_START, S_FWD_SCHED_WAIT,
    S_FWD_READ, S_FWD_READ_WAIT, S_FWD_NEXT,
    S_MATMUL_U, S_MATMUL_U_CAPTURE, S_MATMUL_U_NEXT,
    S_MATMUL_V, S_MATMUL_V_CAPTURE,
    S_INV_U_LOAD, S_INV_U_SCHED_SETUP, S_INV_U_SCHED_START, S_INV_U_SCHED_WAIT,
    S_INV_U_READ, S_INV_U_READ_WAIT, S_INV_U_SCALE, S_INV_U_ADD_E1, S_INV_U_NEXT,
    S_INV_V_LOAD, S_INV_V_SCHED_SETUP, S_INV_V_SCHED_START, S_INV_V_SCHED_WAIT,
    S_INV_V_READ, S_INV_V_READ_WAIT, S_INV_V_SCALE,
    S_DECODE_MU_SETUP, S_DECODE_MU, S_DECODE_MU_CAPTURE, S_ADD_E2, S_ADD_MU,
    S_COMPRESS_U_SETUP, S_COMPRESS_U, S_ENCODE_U,
    S_COMPRESS_V_SETUP, S_COMPRESS_V, S_ENCODE_V,
    S_START_SHAKE256, S_WAIT_SHAKE256, S_SELECT_K,
    S_DONE
  } state_e;
  state_e state;

  logic [7:0] inv_load_idx, inv_read_idx;
  logic [5:0] inv_sched_idx;
  logic [1:0] inv_col;
  logic [256*COEFF_W-1:0] raw_u, raw_v, scaled_v, mu_poly;
  logic [256*COEFF_W-1:0] u_vec [0:K-1];
  logic [256*COEFF_W-1:0] v_poly;
  logic [7:0] mu_bit_idx;

  always_ff @(posedge clk) begin
    samplentt_start <= 1'b0;
    cbd1_start <= 1'b0;
    cbd2_start <= 1'b0;
    ntt_start <= 1'b0;
    ntt_load_valid <= 1'b0;
    shake256_start <= 1'b0;
    done <= 1'b0;

    if (reset) begin
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: begin
          if (start) begin
            bdec12_in[0] <= ek_in[(0*384)*8 +: 384*8];
            bdec12_in[1] <= ek_in[(1*384)*8 +: 384*8];
            rho <= ek_in[(384*K)*8 +: 32*8];
            state <= S_DECODE_T;
          end
        end

        S_DECODE_T: begin
          for (int cc = 0; cc < 256; cc++) begin
            t_hat[0][cc*COEFF_W +: COEFF_W] <= {4'b0, bdec12_out_raw[0][cc*12 +: 12]};
            t_hat[1][cc*COEFF_W +: COEFF_W] <= {4'b0, bdec12_out_raw[1][cc*12 +: 12]};
          end
          i_ctr <= 2'd0; j_ctr <= 2'd0;
          state <= S_START_SNTT;
        end

        S_START_SNTT: begin
          // KORJAUS 2 (2026-07-19, jatko): AIEMPI vaihto oli VAARIN.
          // Virallisen kpke_encrypt_golden.py:n oma kommentti: "A_hat[i,j]
          // = SampleNTT(rho||j||i) - TASMALLEEN SAMA kuin K-PKE.KeyGen,
          // EI transponoitu generoinnissa. Transponointi tapahtuu VASTA
          // KAAVASSA: u[i] = sum_j A_hat[j][i] * y_hat[j]". Palautettu
          // generointi KeyGenin omaan, EI-transponoituun konventioon -
          // transpoosi toteutetaan sen sijaan matriisikertolaskun omassa
          // indeksoinnissa (S_MATMUL_U).
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
              i_ctr <= 2'd0; n_ctr <= 3'd0;
              state <= S_START_CBD1;
            end else begin
              i_ctr <= i_ctr + 2'd1;
              state <= S_START_SNTT;
            end
          end else begin
            j_ctr <= j_ctr + 2'd1;
            state <= S_START_SNTT;
          end
        end

        // --- y_vec: PRF+CBD(ETA1), N=0..K-1 ---
        S_START_CBD1: begin
          cbd1_seed <= r_prime_in; cbd1_n <= {5'b0,n_ctr};
          cbd1_start <= 1'b1;
          state <= S_WAIT_CBD1;
        end

        S_WAIT_CBD1: begin
          if (cbd1_done) begin
            y_vec[n_ctr[0]] <= cbd1_out;
            if (n_ctr == K-1) begin
              n_ctr <= n_ctr + 3'd1;
              state <= S_START_CBD2;
            end else begin
              n_ctr <= n_ctr + 3'd1;
              state <= S_START_CBD1;
            end
          end
        end

        // --- e1_vec (N=K..2K-1) ja e2_poly (N=2K): PRF+CBD(ETA2) ---
        S_START_CBD2: begin
          cbd2_seed <= r_prime_in; cbd2_n <= {5'b0,n_ctr};
          cbd2_start <= 1'b1;
          state <= S_WAIT_CBD2;
        end

        S_WAIT_CBD2: begin
          if (cbd2_done) begin
            if (n_ctr == 2*K) begin
              e2_poly_out <= cbd2_out;
              fwd_ctr <= 2'd0; load_idx <= 8'd0;
              state <= S_FWD_LOAD;
            end else begin
              e1_vec[n_ctr - K] <= cbd2_out;
              n_ctr <= n_ctr + 3'd1;
              state <= S_START_CBD2;
            end
          end
        end

        // --- B2a: NTT-forward y_vec[0], y_vec[1] -> y_hat[0], y_hat[1]
        // (sama, jo todistettu bring-up-metodologia kuin M4-MLKEM-
        // ORCH-001:ssa ja Decaps Phase A:ssa) ---
        S_FWD_LOAD: begin
          ntt_load_valid <= 1'b1;
          ntt_load_addr  <= load_idx;
          ntt_load_data  <= y_vec[fwd_ctr][load_idx*COEFF_W +: COEFF_W];
          if (load_idx == 8'd255) begin
            sched_idx <= 6'd0;
            state <= S_FWD_SCHED_SETUP;
          end else load_idx <= load_idx + 8'd1;
        end

        S_FWD_SCHED_SETUP: begin
          ntt_load_valid <= 1'b0;
          begin
            logic [71:0] entry;
            entry = fwd_schedule_rom[sched_idx];
            ntt_count       <= entry[65:58];
            ntt_pair_dist   <= entry[57:50];
            base_addr_lane0 <= entry[49:41];
            zeta_lane0      <= entry[40:25];
            base_addr_lane1 <= entry[24:16];
            zeta_lane1      <= entry[15:0];
          end
          ntt_mode <= 1'b0;
          state <= S_FWD_SCHED_START;
        end

        S_FWD_SCHED_START: begin
          ntt_start <= 1'b1;
          state <= S_FWD_SCHED_WAIT;
        end

        S_FWD_SCHED_WAIT: begin
          if (stage_done) begin
            if (sched_idx == 6'd63) begin
              read_idx <= 8'd0;
              state <= S_FWD_READ;
            end else begin
              sched_idx <= sched_idx + 6'd1;
              state <= S_FWD_SCHED_SETUP;
            end
          end
        end

        S_FWD_READ: state <= S_FWD_READ_WAIT;

        S_FWD_READ_WAIT: begin
          if (ntt_read_valid) begin
            y_hat[fwd_ctr][read_idx*COEFF_W +: COEFF_W] <= ntt_read_data;
            if (read_idx == 8'd255) state <= S_FWD_NEXT;
            else begin
              read_idx <= read_idx + 8'd1;
              state <= S_FWD_READ;
            end
          end
        end

        S_FWD_NEXT: begin
          if (fwd_ctr == K-1) begin
            mm_col <= 2'd0; mm_j <= 2'd0;
            for (int cc = 0; cc < K; cc++) u_acc[cc] <= '0;
            v_acc <= '0;
            state <= S_MATMUL_U;
          end else begin
            fwd_ctr <= fwd_ctr + 2'd1;
            load_idx <= 8'd0;
            state <= S_FWD_LOAD;
          end
        end

        // --- B2b-1: pisteittainen kertolasku + akkumulointi NTT-
        // alueella. EI VIELA inverse-NTT:ta - vain lineaarialgebra
        // NTT-domainissa todennetaan tassa vaiheessa (kayttajan oma
        // rajaus). u_acc[col] = sum_j(A[j][col]*y_hat[j]).
        //
        // KORJAUS (2026-07-19): alkuperainen yksisyklinen versio luki
        // padd_sum:n SAMALLA syklilla kuin asetti padd_a/padd_b:n -
        // sama bugiluokka kuin aiemmin loydetty ja korjattu NTT-luku/
        // Compress-virhe. Korjattu kaksivaiheisella setup/capture-
        // tilaparilla (aseta operandit, VASTA seuraavalla syklilla
        // kaappaa summa). ---
        S_MATMUL_U: begin
          padd_a <= u_acc[mm_col];
          padd_b <= mntt_h;
          state <= S_MATMUL_U_CAPTURE;
        end

        S_MATMUL_U_CAPTURE: begin
          u_acc[mm_col] <= padd_sum;
          if (mm_j == K-1) begin
            mm_j <= 2'd0;
            state <= S_MATMUL_U_NEXT;
          end else begin
            mm_j <= mm_j + 2'd1;
            state <= S_MATMUL_U;
          end
        end

        S_MATMUL_U_NEXT: begin
          if (mm_col == K-1) state <= S_MATMUL_V;
          else begin
            mm_col <= mm_col + 2'd1;
            state <= S_MATMUL_U;
          end
        end

        // --- v_acc = sum_j(t_hat[j]*y_hat[j]) - sama kaksivaiheinen korjaus ---
        S_MATMUL_V: begin
          padd_a <= v_acc;
          padd_b <= mntt_h;
          state <= S_MATMUL_V_CAPTURE;
        end

        S_MATMUL_V_CAPTURE: begin
          v_acc <= padd_sum;
          if (mm_j == K-1) begin
            inv_col <= 2'd0; inv_load_idx <= 8'd0;
            state <= S_INV_U_LOAD;
          end else begin
            mm_j <= mm_j + 2'd1;
            state <= S_MATMUL_V;
          end
        end

        // --- B2b-2: inverse-NTT + skaalaus u_acc[col]:lle, +e1_vec[col] -> u_vec[col] ---
        S_INV_U_LOAD: begin
          ntt_load_valid <= 1'b1;
          ntt_load_addr  <= inv_load_idx;
          ntt_load_data  <= u_acc[inv_col][inv_load_idx*COEFF_W +: COEFF_W];
          if (inv_load_idx == 8'd255) begin
            inv_sched_idx <= 6'd0;
            state <= S_INV_U_SCHED_SETUP;
          end else inv_load_idx <= inv_load_idx + 8'd1;
        end

        S_INV_U_SCHED_SETUP: begin
          ntt_load_valid <= 1'b0;
          begin
            logic [71:0] entry;
            entry = inv_schedule_rom[inv_sched_idx];
            ntt_count       <= entry[65:58];
            ntt_pair_dist   <= entry[57:50];
            base_addr_lane0 <= entry[49:41];
            zeta_lane0      <= entry[40:25];
            base_addr_lane1 <= entry[24:16];
            zeta_lane1      <= entry[15:0];
          end
          ntt_mode <= 1'b1;
          state <= S_INV_U_SCHED_START;
        end

        S_INV_U_SCHED_START: begin
          ntt_start <= 1'b1;
          state <= S_INV_U_SCHED_WAIT;
        end

        S_INV_U_SCHED_WAIT: begin
          if (stage_done) begin
            if (inv_sched_idx == 6'd63) begin
              inv_read_idx <= 8'd0;
              state <= S_INV_U_READ;
            end else begin
              inv_sched_idx <= inv_sched_idx + 6'd1;
              state <= S_INV_U_SCHED_SETUP;
            end
          end
        end

        S_INV_U_READ: state <= S_INV_U_READ_WAIT;

        S_INV_U_READ_WAIT: begin
          if (ntt_read_valid) begin
            raw_u[inv_read_idx*COEFF_W +: COEFF_W] <= ntt_read_data;
            if (inv_read_idx == 8'd255) state <= S_INV_U_SCALE;
            else begin
              inv_read_idx <= inv_read_idx + 8'd1;
              state <= S_INV_U_READ;
            end
          end
        end

        S_INV_U_SCALE: begin
          scale_in <= raw_u;
          state <= S_INV_U_ADD_E1;
        end

        S_INV_U_ADD_E1: begin
          padd_a <= scale_out;
          padd_b <= e1_vec[inv_col];
          state <= S_INV_U_NEXT;
        end

        S_INV_U_NEXT: begin
          u_vec[inv_col] <= padd_sum;
          if (inv_col == K-1) begin
            inv_load_idx <= 8'd0;
            state <= S_INV_V_LOAD;
          end else begin
            inv_col <= inv_col + 2'd1;
            inv_load_idx <= 8'd0;
            state <= S_INV_U_LOAD;
          end
        end

        // --- inverse-NTT + skaalaus v_acc:lle (ei viela e2/mu-lisaysta) ---
        S_INV_V_LOAD: begin
          ntt_load_valid <= 1'b1;
          ntt_load_addr  <= inv_load_idx;
          ntt_load_data  <= v_acc[inv_load_idx*COEFF_W +: COEFF_W];
          if (inv_load_idx == 8'd255) begin
            inv_sched_idx <= 6'd0;
            state <= S_INV_V_SCHED_SETUP;
          end else inv_load_idx <= inv_load_idx + 8'd1;
        end

        S_INV_V_SCHED_SETUP: begin
          ntt_load_valid <= 1'b0;
          begin
            logic [71:0] entry;
            entry = inv_schedule_rom[inv_sched_idx];
            ntt_count       <= entry[65:58];
            ntt_pair_dist   <= entry[57:50];
            base_addr_lane0 <= entry[49:41];
            zeta_lane0      <= entry[40:25];
            base_addr_lane1 <= entry[24:16];
            zeta_lane1      <= entry[15:0];
          end
          ntt_mode <= 1'b1;
          state <= S_INV_V_SCHED_START;
        end

        S_INV_V_SCHED_START: begin
          ntt_start <= 1'b1;
          state <= S_INV_V_SCHED_WAIT;
        end

        S_INV_V_SCHED_WAIT: begin
          if (stage_done) begin
            if (inv_sched_idx == 6'd63) begin
              inv_read_idx <= 8'd0;
              state <= S_INV_V_READ;
            end else begin
              inv_sched_idx <= inv_sched_idx + 6'd1;
              state <= S_INV_V_SCHED_SETUP;
            end
          end
        end

        S_INV_V_READ: state <= S_INV_V_READ_WAIT;

        S_INV_V_READ_WAIT: begin
          if (ntt_read_valid) begin
            raw_v[inv_read_idx*COEFF_W +: COEFF_W] <= ntt_read_data;
            if (inv_read_idx == 8'd255) state <= S_INV_V_SCALE;
            else begin
              inv_read_idx <= inv_read_idx + 8'd1;
              state <= S_INV_V_READ;
            end
          end
        end

        S_INV_V_SCALE: begin
          scale_in <= raw_v;
          state <= S_DECODE_MU_SETUP;
        end

        // --- mu_poly = Decompress(D=1)(ByteDecode(D=1)(m')) ---
        S_DECODE_MU_SETUP: begin
          scaled_v <= scale_out;
          bdec1_in <= m_prime_in;
          mu_bit_idx <= 8'd0;
          state <= S_DECODE_MU;
        end

        S_DECODE_MU: begin
          c1_d_sel <= 4'd1;
          c1_y_in  <= {15'b0, bdec1_out[mu_bit_idx]};
          state <= S_DECODE_MU_CAPTURE;
        end

        S_DECODE_MU_CAPTURE: begin
          mu_poly[mu_bit_idx*COEFF_W +: COEFF_W] <= c1_decompress_out;
          if (mu_bit_idx == 8'd255) state <= S_ADD_E2;
          else begin
            mu_bit_idx <= mu_bit_idx + 8'd1;
            state <= S_DECODE_MU;
          end
        end

        S_ADD_E2: begin
          padd_a <= scaled_v;
          padd_b <= e2_poly_out;
          state <= S_ADD_MU;
        end

        S_ADD_MU: begin
          padd_a <= padd_sum;
          padd_b <= mu_poly;
          state <= S_COMPRESS_U_SETUP;
        end

        // --- Phase B3: Compress(DU)+ByteEncode(DU) u_vec:lle,
        // Compress(DV)+ByteEncode(DV) v_poly:lle -> c'. Kaksivaiheinen
        // setup/capture-malli (sama periaate kuin kaikkialla muualla). ---
        S_COMPRESS_U_SETUP: begin
          v_poly <= padd_sum;  // viimeistellaan v_poly:n oma laskenta tassa
          bcompu_in[0] <= u_vec[0];
          bcompu_in[1] <= u_vec[1];
          state <= S_COMPRESS_U;
        end

        S_COMPRESS_U: begin
          bencu_in[0] <= bcompu_out[0];
          bencu_in[1] <= bcompu_out[1];
          state <= S_ENCODE_U;
        end

        S_ENCODE_U: begin
          c_prime[(0*DU*32)*8 +: DU*32*8] <= bencu_out[0];
          c_prime[(1*DU*32)*8 +: DU*32*8] <= bencu_out[1];
          bcompv_in <= v_poly;
          state <= S_COMPRESS_V_SETUP;
        end

        S_COMPRESS_V_SETUP: begin
          state <= S_COMPRESS_V;
        end

        S_COMPRESS_V: begin
          bencv_in <= bcompv_out;
          state <= S_ENCODE_V;
        end

        S_ENCODE_V: begin
          c_prime[(2*DU*32)*8 +: DV*32*8] <= bencv_out;
          shake256_msg_in <= '0;
          state <= S_START_SHAKE256;
        end

        // --- Phase B4: FO-valinta. match=(c==c'), K_bar=J(z||c)=
        // SHAKE256(z||c,32), K_final = match ? K' : K_bar ---
        S_START_SHAKE256: begin
          shake256_msg_in[255:0] <= z_in;
          shake256_msg_in[8*768+255:256] <= c_in;
          shake256_start <= 1'b1;
          state <= S_WAIT_SHAKE256;
        end

        S_WAIT_SHAKE256: begin
          if (shake256_done) begin
            match_out <= (c_in === c_prime);
            K_final_out <= (c_in === c_prime) ? K_prime_in : shake256_out;
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

  // --- Litistys: sisaiset unpacked-taulukot -> paketoidut ulostuloportit ---
  assign A_out_flat = {A[1][1], A[1][0], A[0][1], A[0][0]};
  assign y_vec_out_flat = {y_vec[1], y_vec[0]};
  assign y_hat_out_flat = {y_hat[1], y_hat[0]};
  assign e1_vec_out_flat = {e1_vec[1], e1_vec[0]};

  assign ntt_read_en   = (state == S_FWD_READ) || (state == S_FWD_READ_WAIT) ||
                          (state == S_INV_U_READ) || (state == S_INV_U_READ_WAIT) ||
                          (state == S_INV_V_READ) || (state == S_INV_V_READ_WAIT);
  assign ntt_read_addr = ((state == S_INV_U_READ) || (state == S_INV_U_READ_WAIT) ||
                          (state == S_INV_V_READ) || (state == S_INV_V_READ_WAIT)) ? inv_read_idx : read_idx;

  // B2b-1: mntt_f/mntt_g KOMBINATORISIA, indeksoituna rekisteroidyilla
  // mm_j/mm_col:lla - sama, jo todistettu periaate kuin KeyGenin
  // omassa matriisikertolaskussa (EI rekisteroida mntt_f/mntt_g:ta
  // itseaan, koska mntt_h on kombinatorinen niiden pohjalta).
  assign mntt_f = (state == S_MATMUL_V) ? t_hat[mm_j] : A[mm_j][mm_col];
  assign mntt_g = y_hat[mm_j];

  assign u_acc_out_flat = {u_acc[1], u_acc[0]};
  assign v_acc_out = v_acc;
  assign u_vec_out_flat = {u_vec[1], u_vec[0]};
  assign v_poly_out = v_poly;
  assign c_prime_out = c_prime;

endmodule
