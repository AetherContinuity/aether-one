// pqc_mlkem_encaps_tb.sv
//
// M3 Issue #15 (jatko): ML-KEM.Encaps_internal (FIPS 203 Algoritmi 17).
// (K,r) <- G(m||H(ek)); c <- K-PKE.Encrypt(ek,m,r).
//
// HUOM (kayttajan oma tarkennus): K-PKE.Encrypt puretaan SUORAAN ek:sta
// (ByteDecode12(ek[0:384k]) -> t_hat, ek[384k:384k+32] -> rho, sitten
// A regeneroidaan rho:sta) - EI toisteta koko KeyGenin s/e-naytteenottoa.
// Tama vastaa FIPS 203 Algoritmi 14:n rivien 2-8 tarkkaa rakennetta.

`timescale 1ns/1ps

module pqc_mlkem_encaps_tb;

  localparam int COEFF_W = 16;
  localparam int SPAD_AW = 9;
  localparam int K = 2;
  localparam int ETA1 = 3;
  localparam int ETA2 = 2;
  localparam int DU = 10;
  localparam int DV = 4;

  logic clk, reset;
  always #5 clk = ~clk;

  // --- NTT-ajuri ---
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

  // --- SHA3-256 (H), SHA3-512 (G) ---
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

  // --- ByteDecode12 (t_hat:n purku ek:sta) ---
  logic [256*12-1:0] bdec12_in [0:1];
  logic [256*12-1:0] bdec12_out [0:1];
  pqc_bytedecode_dparam #(.D(12)) bdec12_0 (.b_in(bdec12_in[0]), .f_out(bdec12_out[0]));
  pqc_bytedecode_dparam #(.D(12)) bdec12_1 (.b_in(bdec12_in[1]), .f_out(bdec12_out[1]));

  // --- SampleNTT (A) ---
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

  // --- PRF+SamplePolyCBD (eta1, eta2) ---
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

  // --- Testivektorit ---
  logic [8*800-1:0] ek;
  logic [255:0] m_original;
  logic [255:0] H_ek_expect;
  logic [255:0] K_expect;
  logic [255:0] r_expect;
  logic [8*768-1:0] c_expect;

  int fh, scan_ok, error_count;

  initial begin
    error_count = 0;
    clk = 0; reset = 1;
    ntt_start = 0; count = 0; pair_dist = 0; mode = 0;
    base_addr_lane0 = 0; base_addr_lane1 = 0; zeta_lane0 = 0; zeta_lane1 = 0;
    sha256_start = 0; sha512_start = 0; samplentt_start = 0; cbd1_start = 0; cbd2_start = 0;

    $readmemh("m2-golden/bank_rom_4banks.memh", bank_rom_tb);
    $readmemh("m2-golden/bank_local_4banks.memh", local_rom_tb);

    fh = $fopen("vectors/mlkem_encaps_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", ek);
    scan_ok = $fscanf(fh, "%h\n", m_original);
    scan_ok = $fscanf(fh, "%h\n", H_ek_expect);
    scan_ok = $fscanf(fh, "%h\n", K_expect);
    scan_ok = $fscanf(fh, "%h\n", r_expect);
    scan_ok = $fscanf(fh, "%h\n", c_expect);
    $fclose(fh);

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);

    // --- Vaihe 1: H(ek) = SHA3-256(ek), 800 tavua ---
    sha256_msg_in = '0;
    sha256_msg_in[8*800-1:0] = ek;
    sha256_start <= 1'b1; @(posedge clk); sha256_start <= 1'b0;
    while (!sha256_done) @(posedge clk);
    #1;
    if (sha256_out !== H_ek_expect) begin
      $display("FAIL H(ek): poikkeaa golden-mallista"); error_count++;
    end else $display("OK H(ek) (SHA3-256, 800 tavua): tasmaa golden-malliin");

    begin
      logic [255:0] H_ek_captured;
      H_ek_captured = sha256_out;  // tallenna ENNEN resetointia (reset tyhjentaisi rekisterin)

      // --- Vaihe 2: (K,r) = G(m||H(ek)) ---
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
      sha512_msg_in = '0;
      sha512_msg_in[255:0] = m_original;
      sha512_msg_in[511:256] = H_ek_captured;
    sha512_start <= 1'b1; @(posedge clk); sha512_start <= 1'b0;
    while (!sha512_done) @(posedge clk);
    #1;
    begin
      logic [255:0] K_got, r_got;
      K_got = sha512_out[255:0];
      r_got = sha512_out[511:256];
      if (K_got !== K_expect) begin
        $display("FAIL K: poikkeaa golden-mallista"); error_count++;
      end else $display("OK K (G(m||H(ek)):n 1. puolisko): tasmaa golden-malliin");
      if (r_got !== r_expect) begin
        $display("FAIL r: poikkeaa golden-mallista"); error_count++;
      end else $display("OK r (G(m||H(ek)):n 2. puolisko): tasmaa golden-malliin");

      // --- Vaihe 3: K-PKE.Encrypt(ek, m, r) -> c ---
      // Puretaan t_hat ja rho SUORAAN ek:sta (FIPS 203 Alg. 14 rivit 2-3)
      begin
        logic [256*COEFF_W-1:0] t_hat [0:K-1];
        logic [256*COEFF_W-1:0] A [0:K-1][0:K-1];
        logic [255:0] rho;

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
            A[i][j] = samplentt_out;
          end
        end

        begin
          logic [256*COEFF_W-1:0] y_vec [0:K-1], e1_vec [0:K-1], e2_poly;
          logic [256*COEFF_W-1:0] y_hat [0:K-1];
          logic [256*COEFF_W-1:0] u_vec [0:K-1], v_poly;
          logic [8*768-1:0] c_got;
          int Nenc;

          Nenc = 0;
          for (int i = 0; i < K; i++) begin
            cbd1_seed = r_got; cbd1_n = Nenc[7:0];
            reset = 1; @(posedge clk); reset = 0; @(posedge clk);
            cbd1_start <= 1'b1; @(posedge clk); cbd1_start <= 1'b0;
            while (!cbd1_done) @(posedge clk);
            #1;
            y_vec[i] = cbd1_out;
            Nenc++;
          end
          for (int i = 0; i < K; i++) begin
            cbd2_seed = r_got; cbd2_n = Nenc[7:0];
            reset = 1; @(posedge clk); reset = 0; @(posedge clk);
            cbd2_start <= 1'b1; @(posedge clk); cbd2_start <= 1'b0;
            while (!cbd2_done) @(posedge clk);
            #1;
            e1_vec[i] = cbd2_out;
            Nenc++;
          end
          cbd2_seed = r_got; cbd2_n = Nenc[7:0];
          reset = 1; @(posedge clk); reset = 0; @(posedge clk);
          cbd2_start <= 1'b1; @(posedge clk); cbd2_start <= 1'b0;
          while (!cbd2_done) @(posedge clk);
          #1;
          e2_poly = cbd2_out;

          for (int i = 0; i < K; i++) run_forward_ntt(y_vec[i], y_hat[i]);

          for (int col = 0; col < K; col++) begin
            logic [256*COEFF_W-1:0] acc, raw, scaled;
            acc = '0;
            for (int j = 0; j < K; j++) begin
              mntt_f = A[j][col]; mntt_g = y_hat[j];
              #1;
              padd_a = acc; padd_b = mntt_h;
              #1;
              acc = padd_sum;
            end
            run_inverse_ntt(acc, raw);
            scale_in = raw; #1; scaled = scale_out;
            padd_a = scaled; padd_b = e1_vec[col];
            #1;
            u_vec[col] = padd_sum;
          end

          begin
            logic [256*COEFF_W-1:0] acc, raw, scaled, mu_poly;
            acc = '0;
            for (int j = 0; j < K; j++) begin
              mntt_f = t_hat[j]; mntt_g = y_hat[j];
              #1;
              padd_a = acc; padd_b = mntt_h;
              #1;
              acc = padd_sum;
            end
            run_inverse_ntt(acc, raw);
            scale_in = raw; #1; scaled = scale_out;

            bdec1_in = m_original;
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

          c_got = '0;
          c_got[(0*DU*32)*8 +: DU*32*8] = benc_u_out[0];
          c_got[(1*DU*32)*8 +: DU*32*8] = benc_u_out[1];
          c_got[(2*DU*32)*8 +: DV*32*8] = benc_v_out;

          if (c_got !== c_expect) begin
            $display("FAIL c (ciphertext): poikkeaa golden-mallista"); error_count++;
          end else $display("OK c (K-PKE.Encrypt(ek,m,r), %0d tavua): tasmaa golden-malliin", 768);
        end
      end
    end
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: ML-KEM.Encaps_internal(ek,m) -> (K,c) tasmaa golden-malliin");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
