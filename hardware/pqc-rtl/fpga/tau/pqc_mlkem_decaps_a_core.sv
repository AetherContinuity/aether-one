// pqc_mlkem_decaps_a_core.sv
//
// M4-DECAPS-ORCH-001 Phase A: K-PKE.Decrypt(dkPKE, c) -> m'
// (FIPS 203 Algoritmi 15, ML-KEM.Decaps_internal:n ensimmainen osa).
//
// SEKVENSSI (vastaa tb/pqc_mlkem_decaps_a_tb.sv:n proseduraalista
// orkestrointia, nyt synteesikelpoisena tilakoneena):
// 1. Pura c -> c1[0], c1[1] (DU=10-bittinen), c2 (DV=4-bittinen)
// 2. ByteDecode(DU) + Decompress(DU) c1[i]:sta -> u'[i]
// 3. ByteDecode(DV) + Decompress(DV) c2:sta -> v'
// 4. ByteDecode(12) dkPKE:sta -> s_hat[i]
// 5. NTT-forward u'[i]:lle -> u_hat[i]
// 6. Matriisikertolasku+summaus: acc = sum_i(s_hat[i]*u_hat[i])
// 7. NTT-inverse acc:lle -> inner_raw -> scale -> inner
// 8. w = v' - inner
// 9. Compress(D=1) + ByteEncode(D=1) w:sta -> m'
//
// TAMA ON TUTKIMUSPROTOTYYPPI (fpga/tau/) - EI VIELA tuotanto-
// integraatiota. Kayttaa uudelleen M4-MLKEM-ORCH-001:n (KeyGen)
// todistettua NTT-forward-metodologiaa, laajennettuna NTT-inverse-
// kykyyn (uusi aikataulu-ROM, mode=1).

`timescale 1ns/1ps

module pqc_mlkem_decaps_a_core #(
    parameter int COEFF_W = 16,
    parameter int SPAD_AW = 9,
    parameter int K = 2,
    parameter int DU = 10,
    parameter int DV = 4
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [8*768-1:0] c_in,      // tiiviisti pakattu siffertext (768 tavua)
    input  logic [8*768-1:0] dkPKE_in,  // dkPKE (768 tavua, K*384)
    input  logic [255:0] h_in,          // H(ek), G-vaiheen syote

    output logic done,
    output logic [255:0] m_prime_out,
    output logic [255:0] K_prime_out,
    output logic [255:0] r_prime_out
);

  // --- NTT-ydin (bring-up-rajapinta, sama kuin KeyGenissa) ---
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

  // --- Aikataulu-ROMit: forward (KeyGenista uudelleenkaytetty) ja
  // inverse (uusi, taso 6 VIIMEISENA) ---
  logic [71:0] fwd_schedule_rom [0:63];
  logic [71:0] inv_schedule_rom [0:63];
  initial begin
    $readmemh("fpga/tau/mlkem_ntt_schedule_rom.memh", fwd_schedule_rom);
    $readmemh("fpga/tau/mlkem_ntt_inverse_schedule_rom.memh", inv_schedule_rom);
  end

  // --- Kombinatoriset alimoduulit ---
  logic [256*DU-1:0] bdecU_in [0:1];
  logic [256*DU-1:0] bdecU_out [0:1];
  pqc_bytedecode_dparam #(.D(DU)) bdecU0 (.b_in(bdecU_in[0]), .f_out(bdecU_out[0]));
  pqc_bytedecode_dparam #(.D(DU)) bdecU1 (.b_in(bdecU_in[1]), .f_out(bdecU_out[1]));

  logic [256*DU-1:0] decompU_in [0:1];
  logic [256*COEFF_W-1:0] decompU_out [0:1];
  pqc_batch_decompress #(.D(DU), .COEFF_W(COEFF_W)) decompU0 (.y_packed(decompU_in[0]), .x_packed(decompU_out[0]));
  pqc_batch_decompress #(.D(DU), .COEFF_W(COEFF_W)) decompU1 (.y_packed(decompU_in[1]), .x_packed(decompU_out[1]));

  logic [256*DV-1:0] bdecV_in;
  logic [256*DV-1:0] bdecV_out;
  pqc_bytedecode_dparam #(.D(DV)) bdecV (.b_in(bdecV_in), .f_out(bdecV_out));

  logic [256*DV-1:0] decompV_in;
  logic [256*COEFF_W-1:0] decompV_out;
  pqc_batch_decompress #(.D(DV), .COEFF_W(COEFF_W)) decompV (.y_packed(decompV_in), .x_packed(decompV_out));

  logic [256*12-1:0] bdec12_in [0:1];
  logic [256*12-1:0] bdec12_out_raw [0:1];
  pqc_bytedecode_dparam #(.D(12)) bdec12_0 (.b_in(bdec12_in[0]), .f_out(bdec12_out_raw[0]));
  pqc_bytedecode_dparam #(.D(12)) bdec12_1 (.b_in(bdec12_in[1]), .f_out(bdec12_out_raw[1]));

  logic [256*COEFF_W-1:0] mntt_f, mntt_g, mntt_h;
  pqc_multiplyntts #(.COEFF_W(COEFF_W)) mntt_dut (.f_hat(mntt_f), .g_hat(mntt_g), .h_hat(mntt_h));

  logic [256*COEFF_W-1:0] padd_a, padd_b, padd_sum;
  pqc_polyadd #(.COEFF_W(COEFF_W)) padd_dut (.a_in(padd_a), .b_in(padd_b), .sum_out(padd_sum));

  logic [256*COEFF_W-1:0] psub_a, psub_b, psub_diff;
  pqc_polysub #(.COEFF_W(COEFF_W)) psub_dut (.a_in(psub_a), .b_in(psub_b), .diff_out(psub_diff));

  logic [256*COEFF_W-1:0] scale_in, scale_out;
  pqc_ntt_final_scale #(.COEFF_W(COEFF_W)) scale_dut (.f_in(scale_in), .f_out(scale_out));

  logic [COEFF_W-1:0] c1_x_in;
  logic [COEFF_W-1:0] c1_compress_out;
  logic [3:0] c1_d_sel;
  pqc_compress #(.COEFF_W(COEFF_W)) compress1_dut (
    .d(c1_d_sel), .x_in(c1_x_in), .compress_out(c1_compress_out),
    .y_in('0), .decompress_out()
  );

  logic [255:0] benc1_in, benc1_out;
  pqc_byteencode_d1 benc1_dut (.f_in(benc1_in), .b_out(benc1_out));

  logic sha512_start, sha512_done;
  logic [8*72-1:0] sha512_msg_in;
  logic [511:0] sha512_out;
  pqc_sha3_512 #(.MAX_BLOCKS(1)) sha512_dut (
    .clk(clk), .reset(reset), .start(sha512_start),
    .msg_in(sha512_msg_in), .msg_len_bytes(16'd64),
    .digest_out(sha512_out), .done(sha512_done)
  );

  // --- Tallennusrekisterit ---
  logic [256*COEFF_W-1:0] u_prime [0:K-1], v_prime;
  logic [256*COEFF_W-1:0] s_hat [0:K-1];
  logic [256*COEFF_W-1:0] u_hat [0:K-1];
  logic [256*COEFF_W-1:0] mm_acc;
  logic [256*COEFF_W-1:0] inner_raw, inner, w;

  // --- Paatilakone ---
  typedef enum logic [4:0] {
    S_IDLE, S_DECODE_U_V, S_DECODE_S,
    S_FWD_LOAD, S_FWD_SCHED_SETUP, S_FWD_SCHED_START, S_FWD_SCHED_WAIT, S_FWD_READ, S_FWD_READ_WAIT, S_FWD_NEXT,
    S_MATMUL, S_MATMUL_NEXT,
    S_INV_LOAD, S_INV_SCHED_SETUP, S_INV_SCHED_START, S_INV_SCHED_WAIT, S_INV_READ, S_INV_READ_WAIT,
    S_SCALE, S_SUB, S_ENCODE_M_SETUP, S_ENCODE_M,
    S_START_SHA512, S_WAIT_SHA512, S_DONE
  } state_e;
  state_e state;

  logic [1:0] fwd_ctr;
  logic [5:0] sched_idx;
  logic [7:0] load_idx, read_idx;
  logic [1:0] mm_i;
  logic [7:0] m_bit_idx;

  always_ff @(posedge clk) begin
    ntt_start <= 1'b0;
    ntt_load_valid <= 1'b0;
    sha512_start <= 1'b0;
    done <= 1'b0;

    if (reset) begin
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: begin
          if (start) begin
            // --- ByteDecode+Decompress: kombinatorinen, yksi sykli riittaa ---
            bdecU_in[0] <= c_in[(0*DU*32)*8 +: DU*32*8];
            bdecU_in[1] <= c_in[(1*DU*32)*8 +: DU*32*8];
            bdecV_in    <= c_in[(2*DU*32)*8 +: DV*32*8];
            bdec12_in[0] <= dkPKE_in[(0*384)*8 +: 384*8];
            bdec12_in[1] <= dkPKE_in[(1*384)*8 +: 384*8];
            state <= S_DECODE_U_V;
          end
        end

        S_DECODE_U_V: begin
          decompU_in[0] <= bdecU_out[0];
          decompU_in[1] <= bdecU_out[1];
          decompV_in    <= bdecV_out;
          state <= S_DECODE_S;
        end

        S_DECODE_S: begin
          u_prime[0] <= decompU_out[0];
          u_prime[1] <= decompU_out[1];
          v_prime    <= decompV_out;
          for (int cc = 0; cc < 256; cc++) begin
            s_hat[0][cc*COEFF_W +: COEFF_W] <= {4'b0, bdec12_out_raw[0][cc*12 +: 12]};
            s_hat[1][cc*COEFF_W +: COEFF_W] <= {4'b0, bdec12_out_raw[1][cc*12 +: 12]};
          end
          fwd_ctr <= 2'd0;
          load_idx <= 8'd0;
          state <= S_FWD_LOAD;
        end

        // --- NTT-forward u'[0], u'[1] -> u_hat[0], u_hat[1] ---
        S_FWD_LOAD: begin
          ntt_load_valid <= 1'b1;
          ntt_load_addr  <= load_idx;
          ntt_load_data  <= (fwd_ctr == 0) ? u_prime[0][load_idx*COEFF_W +: COEFF_W]
                                            : u_prime[1][load_idx*COEFF_W +: COEFF_W];
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
            if (fwd_ctr == 0) u_hat[0][read_idx*COEFF_W +: COEFF_W] <= ntt_read_data;
            else u_hat[1][read_idx*COEFF_W +: COEFF_W] <= ntt_read_data;
            if (read_idx == 8'd255) state <= S_FWD_NEXT;
            else begin
              read_idx <= read_idx + 8'd1;
              state <= S_FWD_READ;
            end
          end
        end

        S_FWD_NEXT: begin
          if (fwd_ctr == K-1) begin
            mm_i <= 2'd0;
            mm_acc <= '0;
            state <= S_MATMUL;
          end else begin
            fwd_ctr <= fwd_ctr + 2'd1;
            load_idx <= 8'd0;
            state <= S_FWD_LOAD;
          end
        end

        // --- Matriisikertolasku: acc = sum_i(s_hat[i]*u_hat[i]) ---
        S_MATMUL: begin
          mm_acc <= padd_sum;
          if (mm_i == K-1) begin
            load_idx <= 8'd0;
            state <= S_INV_LOAD;
          end else mm_i <= mm_i + 2'd1;
        end

        // --- NTT-inverse mm_acc:lle -> inner_raw ---
        S_INV_LOAD: begin
          ntt_load_valid <= 1'b1;
          ntt_load_addr  <= load_idx;
          ntt_load_data  <= mm_acc[load_idx*COEFF_W +: COEFF_W];
          if (load_idx == 8'd255) begin
            sched_idx <= 6'd0;
            state <= S_INV_SCHED_SETUP;
          end else load_idx <= load_idx + 8'd1;
        end

        S_INV_SCHED_SETUP: begin
          ntt_load_valid <= 1'b0;
          begin
            logic [71:0] entry;
            entry = inv_schedule_rom[sched_idx];
            ntt_count       <= entry[65:58];
            ntt_pair_dist   <= entry[57:50];
            base_addr_lane0 <= entry[49:41];
            zeta_lane0      <= entry[40:25];
            base_addr_lane1 <= entry[24:16];
            zeta_lane1      <= entry[15:0];
          end
          ntt_mode <= 1'b1;  // INVERSE
          state <= S_INV_SCHED_START;
        end

        S_INV_SCHED_START: begin
          ntt_start <= 1'b1;
          state <= S_INV_SCHED_WAIT;
        end

        S_INV_SCHED_WAIT: begin
          if (stage_done) begin
            if (sched_idx == 6'd63) begin
              read_idx <= 8'd0;
              state <= S_INV_READ;
            end else begin
              sched_idx <= sched_idx + 6'd1;
              state <= S_INV_SCHED_SETUP;
            end
          end
        end

        S_INV_READ: state <= S_INV_READ_WAIT;

        S_INV_READ_WAIT: begin
          if (ntt_read_valid) begin
            inner_raw[read_idx*COEFF_W +: COEFF_W] <= ntt_read_data;
            if (read_idx == 8'd255) state <= S_SCALE;
            else begin
              read_idx <= read_idx + 8'd1;
              state <= S_INV_READ;
            end
          end
        end

        S_SCALE: begin
          inner <= scale_out;
          state <= S_SUB;
        end

        S_SUB: begin
          w <= psub_diff;
          m_bit_idx <= 8'd0;
          state <= S_ENCODE_M_SETUP;
        end

        // M4-DECAPS-ORCH-001 debug-korjaus: c1_x_in on rekisteroity,
        // c1_compress_out on kombinatorinen sen POHJALTA - tarvitaan
        // KAKSI erillista sykli-vaihetta (aseta x_in, sitten VASTA
        // seuraavalla syklilla kaappaa compress_out) - sama periaate
        // kuin aiemmin loydetty ja korjattu NTT-luku/kirjoitusvirhe.
        S_ENCODE_M_SETUP: begin
          c1_d_sel <= 4'd1;
          c1_x_in  <= w[m_bit_idx*COEFF_W +: COEFF_W];
          state <= S_ENCODE_M;
        end

        S_ENCODE_M: begin
          benc1_in[m_bit_idx] <= c1_compress_out[0];
          if (m_bit_idx == 8'd255) begin
            sha512_msg_in <= '0;
            state <= S_START_SHA512;
          end else begin
            m_bit_idx <= m_bit_idx + 8'd1;
            state <= S_ENCODE_M_SETUP;
          end
        end

        // --- G(m'||h) -> (K', r') - sama kaava kuin M4-MLKEM-
        // ORCH-001:ssa (KeyGenin oma SHA3-512-vaihe) ---
        S_START_SHA512: begin
          sha512_msg_in[255:0]   <= benc1_out;
          sha512_msg_in[511:256] <= h_in;
          sha512_start <= 1'b1;
          state <= S_WAIT_SHA512;
        end

        S_WAIT_SHA512: begin
          if (sha512_done) begin
            K_prime_out <= sha512_out[255:0];
            r_prime_out <= sha512_out[511:256];
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

  // --- Kombinatorinen kytkenta ---
  assign ntt_read_en   = (state == S_FWD_READ) || (state == S_FWD_READ_WAIT) ||
                          (state == S_INV_READ) || (state == S_INV_READ_WAIT);
  assign ntt_read_addr = read_idx;

  assign mntt_f = s_hat[mm_i];
  assign mntt_g = u_hat[mm_i];
  assign padd_a = mm_acc;
  assign padd_b = mntt_h;

  assign scale_in = inner_raw;
  assign psub_a = v_prime;
  assign psub_b = inner;

  assign m_prime_out = benc1_out;

endmodule
