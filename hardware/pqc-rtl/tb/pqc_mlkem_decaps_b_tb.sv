// pqc_mlkem_decaps_b_tb.sv
//
// M3 Issue #15 (jatko): Decaps TB B - toinen puolisko
// ML-KEM.Decaps_internal:sta. m',r',ek,z syotteina (jo laskettu
// TB A:ssa/golden-mallissa) -> K-PKE.Encrypt(ek,m',r') -> c',
// tavu-tavulta-vertailu c==c' (ensimmainen eroava tavu debugiin),
// FO-valinta (K' tai J(z||c)). Testataan kaikki kolme jaadytettya
// tapausta.
//
// HUOM: TAMA testipenkki EI sisalla K-PKE.Decryptin omia moduuleita
// (ByteDecode/Decompress u/v-puolelle) - vain Encrypt-puoli tarvitaan.
// Pienempi moduulimaara kuin epaonnistuneessa yhdistetyssa testissa -
// valttaa VVP:n oman segmentointivirheen.

`timescale 1ns/1ps

module pqc_mlkem_decaps_b_tb;

  localparam int COEFF_W = 16;
  localparam int SPAD_AW = 9;
  localparam int K = 2;
  localparam int ETA1 = 3;
  localparam int ETA2 = 2;
  localparam int DU = 10;
  localparam int DV = 4;

  logic clk, reset;
  always #5 clk = ~clk;

  logic ntt_start, stage_done, bank_conflict_detected;
  logic [7:0] count, pair_dist;
  logic mode;
  logic [SPAD_AW-1:0] base_addr_lane0, base_addr_lane1;
  logic [COEFF_W-1:0] zeta_lane0, zeta_lane1;

  pqc_ntt_stage_banked #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW)) ntt_dut (
    .clk(clk), .reset(reset), .start(ntt_start), .count(count),
    .pair_dist(pair_dist), .mode(mode),
    .base_addr_lane0(base_addr_lane0), .base_addr_lane1(base_addr_lane1),
    .zeta_lane0(zeta_lane0), .zeta_lane1(zeta_lane1),
    .stage_done(stage_done), .bank_conflict_detected(bank_conflict_detected),
    .load_valid(1'b0), .load_addr(8'd0), .load_data(16'd0), .read_en(1'b0), .read_addr(8'd0), .read_valid(), .read_data()
  );

  logic [1:0] bank_rom_tb  [0:255];
  logic [5:0] local_rom_tb [0:255];

  function automatic void write_bank(input [1:0] b, input [5:0] l, input [COEFF_W-1:0] val);
    case (b)
      2'd0: ntt_dut.bank0[l] = val;
      2'd1: ntt_dut.bank1[l] = val;
      2'd2: ntt_dut.bank2[l] = val;
      default: ntt_dut.bank3[l] = val;
    endcase
  endfunction

  function automatic [COEFF_W-1:0] read_bank_tb(input [1:0] b, input [5:0] l);
    case (b)
      2'd0: read_bank_tb = ntt_dut.bank0[l];
      2'd1: read_bank_tb = ntt_dut.bank1[l];
      2'd2: read_bank_tb = ntt_dut.bank2[l];
      default: read_bank_tb = ntt_dut.bank3[l];
    endcase
  endfunction

  task automatic run_one_level(input int length, input int base0, input int zeta0_int,
                                 input int base1, input int zeta1_int, input int count_val);
    int c;
    begin
      pair_dist       <= 8'(length);
      base_addr_lane0 <= 9'(base0);
      base_addr_lane1 <= 9'(base1);
      zeta_lane0      <= zeta0_int[15:0];
      zeta_lane1      <= zeta1_int[15:0];
      count           <= 8'(count_val);
      @(posedge clk);
      ntt_start <= 1'b1;
      @(posedge clk);
      ntt_start <= 1'b0;
      c = 0;
      while (!stage_done && c < 3000) begin @(posedge clk); c++; end
    end
  endtask

  task automatic run_forward_ntt(input logic [256*COEFF_W-1:0] poly_in,
                                   output logic [256*COEFF_W-1:0] poly_out);
    int fh2, length, base0, zeta0, base1, zeta1, scan_ok2;
    begin
      for (int i = 0; i < 256; i++) write_bank(bank_rom_tb[i], local_rom_tb[i], poly_in[i*COEFF_W +: COEFF_W]);
      mode <= 1'b0;
      fh2 = $fopen("vectors/full_level6_zeta.txt", "r");
      scan_ok2 = $fscanf(fh2, "%d\n", zeta0);
      $fclose(fh2);
      run_one_level(128, 0, zeta0, 64, zeta0, 64);
      fh2 = $fopen("vectors/full_schedule.txt", "r");
      scan_ok2 = 5;
      while (!$feof(fh2) && scan_ok2 == 5) begin
        scan_ok2 = $fscanf(fh2, "%d %d %d %d %d\n", length, base0, zeta0, base1, zeta1);
        if (scan_ok2 == 5) run_one_level(length, base0, zeta0, base1, zeta1, length);
      end
      $fclose(fh2);
      for (int i = 0; i < 256; i++) poly_out[i*COEFF_W +: COEFF_W] = read_bank_tb(bank_rom_tb[i], local_rom_tb[i]);
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
    end
  endtask

  task automatic run_inverse_ntt(input logic [256*COEFF_W-1:0] poly_in,
                                   output logic [256*COEFF_W-1:0] poly_out);
    int fh2, length, base0, zeta0, base1, zeta1, scan_ok2;
    begin
      for (int i = 0; i < 256; i++) write_bank(bank_rom_tb[i], local_rom_tb[i], poly_in[i*COEFF_W +: COEFF_W]);
      mode <= 1'b1;
      fh2 = $fopen("vectors/ntt_inverse_schedule.txt", "r");
      scan_ok2 = 5;
      while (!$feof(fh2) && scan_ok2 == 5) begin
        scan_ok2 = $fscanf(fh2, "%d %d %d %d %d\n", length, base0, zeta0, base1, zeta1);
        if (scan_ok2 == 5) run_one_level(length, base0, zeta0, base1, zeta1, length);
      end
      $fclose(fh2);
      fh2 = $fopen("vectors/ntt_inverse_level6_zeta.txt", "r");
      scan_ok2 = $fscanf(fh2, "%d\n", zeta0);
      $fclose(fh2);
      run_one_level(128, 0, zeta0, 64, zeta0, 64);
      for (int i = 0; i < 256; i++) poly_out[i*COEFF_W +: COEFF_W] = read_bank_tb(bank_rom_tb[i], local_rom_tb[i]);
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
    end
  endtask

  logic shake256_start, shake256_done;
  logic [8*136*6-1:0] shake256_msg_in;
  logic [255:0] shake256_out;
  pqc_shake256 #(.MAX_BLOCKS(6), .MAX_OUT_BYTES(32)) shake256_dut (
    .clk(clk), .reset(reset), .start(shake256_start),
    .msg_in(shake256_msg_in), .msg_len_bytes(16'd800), .out_len_bytes(16'd32),
    .out_data(shake256_out), .done(shake256_done)
  );

  logic samplentt_start, samplentt_done, samplentt_err;
  logic [255:0] samplentt_rho;
  logic [7:0] samplentt_j, samplentt_i;
  logic [16*256-1:0] samplentt_out;
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
  logic [16*256-1:0] cbd1_out;
  pqc_prf_samplepolycbd #(.ETA(ETA1)) cbd1_dut (
    .clk(clk), .reset(reset), .start(cbd1_start),
    .seed_s(cbd1_seed), .counter_n(cbd1_n), .f_out(cbd1_out), .done(cbd1_done)
  );

  logic cbd2_start, cbd2_done;
  logic [255:0] cbd2_seed;
  logic [7:0] cbd2_n;
  logic [16*256-1:0] cbd2_out;
  pqc_prf_samplepolycbd #(.ETA(ETA2)) cbd2_dut (
    .clk(clk), .reset(reset), .start(cbd2_start),
    .seed_s(cbd2_seed), .counter_n(cbd2_n), .f_out(cbd2_out), .done(cbd2_done)
  );

  logic [256*COEFF_W-1:0] mntt_f, mntt_g, mntt_h;
  pqc_multiplyntts #(.COEFF_W(COEFF_W)) mntt_dut (.f_hat(mntt_f), .g_hat(mntt_g), .h_hat(mntt_h));
  logic [256*COEFF_W-1:0] padd_a, padd_b, padd_sum;
  pqc_polyadd #(.COEFF_W(COEFF_W)) padd_dut (.a_in(padd_a), .b_in(padd_b), .sum_out(padd_sum));
  logic [256*COEFF_W-1:0] scale_in, scale_out;
  pqc_ntt_final_scale #(.COEFF_W(COEFF_W)) scale_dut (.f_in(scale_in), .f_out(scale_out));

  logic [256*12-1:0] bdec12_in [0:1];
  logic [256*12-1:0] bdec12_out [0:1];
  pqc_bytedecode_dparam #(.D(12)) bdec12_0 (.b_in(bdec12_in[0]), .f_out(bdec12_out[0]));
  pqc_bytedecode_dparam #(.D(12)) bdec12_1 (.b_in(bdec12_in[1]), .f_out(bdec12_out[1]));

  logic [255:0] bdec1_in;
  logic [255:0] bdec1_out;
  pqc_bytedecode_d1 bdec1_dut (.b_in(bdec1_in), .f_out(bdec1_out));

  logic [3:0] c1_d_sel;
  logic [COEFF_W-1:0] c1_x_in, c1_compress_out;
  logic [COEFF_W-1:0] c1_y_in, c1_decompress_out;
  pqc_compress #(.COEFF_W(COEFF_W)) compress1_dut (
    .d(c1_d_sel), .x_in(c1_x_in), .compress_out(c1_compress_out),
    .y_in(c1_y_in), .decompress_out(c1_decompress_out)
  );

  logic [256*COEFF_W-1:0] bcompress_u_in [0:1];
  logic [256*DU-1:0] bcompress_u_out [0:1];
  pqc_batch_compress #(.D(DU), .COEFF_W(COEFF_W)) bcompu0 (.x_packed(bcompress_u_in[0]), .y_packed(bcompress_u_out[0]));
  pqc_batch_compress #(.D(DU), .COEFF_W(COEFF_W)) bcompu1 (.x_packed(bcompress_u_in[1]), .y_packed(bcompress_u_out[1]));
  logic [256*COEFF_W-1:0] bcompress_v_in;
  logic [256*DV-1:0] bcompress_v_out;
  pqc_batch_compress #(.D(DV), .COEFF_W(COEFF_W)) bcompv (.x_packed(bcompress_v_in), .y_packed(bcompress_v_out));

  logic [256*DU-1:0] benc_u_in [0:1];
  logic [256*DU-1:0] benc_u_out [0:1];
  pqc_byteencode_dparam #(.D(DU)) bencu0 (.f_in(benc_u_in[0]), .b_out(benc_u_out[0]));
  pqc_byteencode_dparam #(.D(DU)) bencu1 (.f_in(benc_u_in[1]), .b_out(benc_u_out[1]));
  logic [256*DV-1:0] benc_v_in, benc_v_out;
  pqc_byteencode_dparam #(.D(DV)) bencv (.f_in(benc_v_in), .b_out(benc_v_out));

  logic [8*800-1:0] ek;
  logic [255:0] z_seed;
  int fh, scan_ok, error_count, case_count;
  string tag;
  logic [256*COEFF_W-1:0] A_module [0:K-1][0:K-1];

  initial begin
    error_count = 0; case_count = 0;
    clk = 0; reset = 1;
    ntt_start = 0; count = 0; pair_dist = 0; mode = 0;
    base_addr_lane0 = 0; base_addr_lane1 = 0; zeta_lane0 = 0; zeta_lane1 = 0;
    shake256_start = 0; samplentt_start = 0; cbd1_start = 0; cbd2_start = 0;

    $readmemh("m2-golden/bank_rom_4banks.memh", bank_rom_tb);
    $readmemh("m2-golden/bank_local_4banks.memh", local_rom_tb);

    fh = $fopen("vectors/mlkem_decaps_b_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", ek);
    scan_ok = $fscanf(fh, "%h\n", z_seed);

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);

    for (int tc = 0; tc < 3; tc++) begin
      logic [255:0] m_prime, r_prime, K_prime_expect;
      logic [8*768-1:0] c_variant, c_prime_expect, c_prime_got;
      int match_expect;
      logic [255:0] K_final_expect;
      int first_diff_idx;

      scan_ok = $fscanf(fh, "%s\n", tag);
      scan_ok = $fscanf(fh, "%h\n", m_prime);
      scan_ok = $fscanf(fh, "%h\n", r_prime);
      scan_ok = $fscanf(fh, "%h\n", K_prime_expect);
      scan_ok = $fscanf(fh, "%h\n", c_variant);
      scan_ok = $fscanf(fh, "%h\n", c_prime_expect);
      scan_ok = $fscanf(fh, "%d\n", match_expect);
      scan_ok = $fscanf(fh, "%h\n", K_final_expect);

      // --- K-PKE.Encrypt(ek, m', r') -> c' ---
      begin
        logic [256*COEFF_W-1:0] t_hat [0:K-1];
        logic [255:0] rho;
        logic [256*COEFF_W-1:0] y_vec [0:K-1], e1_vec [0:K-1], e2_poly;
        logic [256*COEFF_W-1:0] y_hat [0:K-1];
        logic [256*COEFF_W-1:0] u_vec [0:K-1], v_poly;
        int Nenc;

        for (int i = 0; i < K; i++) begin
          bdec12_in[i] = ek[(i*384)*8 +: 384*8];
          #1;
          for (int cc = 0; cc < 256; cc++) t_hat[i][cc*COEFF_W +: COEFF_W] = {4'b0, bdec12_out[i][cc*12 +: 12]};
        end
        rho = ek[(384*K)*8 +: 32*8];

        for (int i = 0; i < K; i++) begin
          for (int j = 0; j < K; j++) begin
            samplentt_rho = rho; samplentt_j = j[7:0]; samplentt_i = i[7:0];
            reset = 1; @(posedge clk); reset = 0; @(posedge clk);
            samplentt_start <= 1'b1; @(posedge clk); samplentt_start <= 1'b0;
            while (!samplentt_done) @(posedge clk);
            #1;
            A_module[i][j] = samplentt_out;
          end
        end

        Nenc = 0;
        for (int i = 0; i < K; i++) begin
          cbd1_seed = r_prime; cbd1_n = Nenc[7:0];
          reset = 1; @(posedge clk); reset = 0; @(posedge clk);
          cbd1_start <= 1'b1; @(posedge clk); cbd1_start <= 1'b0;
          while (!cbd1_done) @(posedge clk);
          #1;
          y_vec[i] = cbd1_out;
          Nenc++;
        end
        for (int i = 0; i < K; i++) begin
          cbd2_seed = r_prime; cbd2_n = Nenc[7:0];
          reset = 1; @(posedge clk); reset = 0; @(posedge clk);
          cbd2_start <= 1'b1; @(posedge clk); cbd2_start <= 1'b0;
          while (!cbd2_done) @(posedge clk);
          #1;
          e1_vec[i] = cbd2_out;
          Nenc++;
        end
        cbd2_seed = r_prime; cbd2_n = Nenc[7:0];
        reset = 1; @(posedge clk); reset = 0; @(posedge clk);
        cbd2_start <= 1'b1; @(posedge clk); cbd2_start <= 1'b0;
        while (!cbd2_done) @(posedge clk);
        #1;
        e2_poly = cbd2_out;

        for (int i = 0; i < K; i++) run_forward_ntt(y_vec[i], y_hat[i]);

        for (int col = 0; col < K; col++) begin
          logic [256*COEFF_W-1:0] acc2, raw, scaled;
          acc2 = '0;
          for (int j = 0; j < K; j++) begin
            mntt_f = A_module[j][col]; mntt_g = y_hat[j];
            #1;
            padd_a = acc2; padd_b = mntt_h;
            #1;
            acc2 = padd_sum;
          end
          run_inverse_ntt(acc2, raw);
          scale_in = raw; #1; scaled = scale_out;
          padd_a = scaled; padd_b = e1_vec[col];
          #1;
          u_vec[col] = padd_sum;
        end

        begin
          logic [256*COEFF_W-1:0] acc3, raw, scaled, mu_poly;
          acc3 = '0;
          for (int j = 0; j < K; j++) begin
            mntt_f = t_hat[j]; mntt_g = y_hat[j];
            #1;
            padd_a = acc3; padd_b = mntt_h;
            #1;
            acc3 = padd_sum;
          end
          run_inverse_ntt(acc3, raw);
          scale_in = raw; #1; scaled = scale_out;

          bdec1_in = m_prime;
          #1;
          for (int i = 0; i < 256; i++) begin
            c1_d_sel = 4'd1;
            c1_y_in = {15'b0, bdec1_out[i]};
            #1;
            mu_poly[i*COEFF_W +: COEFF_W] = c1_decompress_out;
          end

          padd_a = scaled; padd_b = e2_poly;
          #1;
          padd_a = padd_sum; padd_b = mu_poly;
          #1;
          v_poly = padd_sum;
        end

        for (int col = 0; col < K; col++) begin
          bcompress_u_in[col] = u_vec[col];
          #1;
          benc_u_in[col] = bcompress_u_out[col];
          #1;
        end
        bcompress_v_in = v_poly;
        #1;
        benc_v_in = bcompress_v_out;
        #1;

        c_prime_got = '0;
        c_prime_got[(0*DU*32)*8 +: DU*32*8] = benc_u_out[0];
        c_prime_got[(1*DU*32)*8 +: DU*32*8] = benc_u_out[1];
        c_prime_got[(2*DU*32)*8 +: DV*32*8] = benc_v_out;
      end

      if (c_prime_got !== c_prime_expect) begin
        $display("FAIL %s: c' poikkeaa golden-mallista", tag); error_count++;
      end else $display("OK %s: c' tasmaa golden-malliin", tag);

      first_diff_idx = -1;
      for (int b = 0; b < 768; b++) begin
        if (c_variant[b*8 +: 8] !== c_prime_got[b*8 +: 8] && first_diff_idx == -1) first_diff_idx = b;
      end
      if (first_diff_idx == -1) $display("    %s: c == c' (kaikki 768 tavua tasmaavat)", tag);
      else $display("    %s: c != c', ensimmainen eroava tavu = %0d", tag, first_diff_idx);

      // --- FO-valinta ---
      begin
        logic match_got;
        logic [255:0] K_bar_got, K_final_got;
        match_got = (c_variant === c_prime_got);
        if ((match_got ? 1 : 0) !== match_expect) begin
          $display("FAIL %s: vertailutulos poikkeaa golden-mallista", tag); error_count++;
        end

        reset = 1; @(posedge clk); reset = 0; @(posedge clk);
        shake256_msg_in = '0;
        shake256_msg_in[255:0] = z_seed;
        shake256_msg_in[8*768+255:256] = c_variant;
        shake256_start <= 1'b1; @(posedge clk); shake256_start <= 1'b0;
        while (!shake256_done) @(posedge clk);
        #1;
        K_bar_got = shake256_out;

        K_final_got = match_got ? K_prime_expect : K_bar_got;

        if (K_final_got !== K_final_expect) begin
          $display("FAIL %s: K_final poikkeaa golden-mallista", tag); error_count++;
        end else $display("OK %s: K_final (%s) tasmaa golden-malliin",
                            tag, match_got ? "normaali K'" : "implisiittinen hylkays J(z||c)");
      end

      case_count++;
    end
    $fclose(fh);

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: Decaps TB B (c', vertailu, FO-valinta kaikille %0d tapaukselle) tasmaa golden-malliin", case_count);
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
