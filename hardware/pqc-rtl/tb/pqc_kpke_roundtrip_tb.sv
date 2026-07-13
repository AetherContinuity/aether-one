// pqc_kpke_roundtrip_tb.sv
//
// M3 Issue #15: TAYDELLINEN integraatiotesti - Seed -> KeyGen ->
// Encrypt -> Decrypt -> alkuperainen viesti. Kayttajan oma ehdotus:
// EI valituja golden-valituloksia valissa - kaikki naytteenotto
// (A, s, e, y, e1, e2) ajetaan AIDOSTI RTL:n omilla sample-moduuleilla
// (pqc_samplentt, pqc_prf_samplepolycbd), ei luetta tiedostosta.
//
// GENUIINISTI ERI m ja r kuin missaan aiemmassa erillisessa testissa
// (0xAA/0x55-toistot) - todistaa etta ketju toimii mielivaltaiselle
// syotteelle.
//
// Paatarkistus: m_decrypted == m_original (Decrypt(Encrypt(m))==m).

`timescale 1ns/1ps

module pqc_kpke_roundtrip_tb;

  localparam int COEFF_W = 16;
  localparam int SPAD_AW = 9;
  localparam int K = 2;
  localparam int ETA1 = 3;
  localparam int ETA2 = 2;
  localparam int DU = 10;
  localparam int DV = 4;

  // --- Yhteinen kello/reset kaikille alimoduuleille ---
  logic clk, reset;
  always #5 clk = ~clk;

  // --- NTT-ajuri (jaettu KeyGen/Encrypt/Decrypt:n kesken) ---
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
    .stage_done(stage_done), .bank_conflict_detected(bank_conflict_detected)
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
    int lines_read;
    begin
      lines_read = 0;
      for (int i = 0; i < 256; i++) write_bank(bank_rom_tb[i], local_rom_tb[i], poly_in[i*COEFF_W +: COEFF_W]);
      mode <= 1'b1;
      fh2 = $fopen("vectors/ntt_inverse_schedule.txt", "r");
      scan_ok2 = 5;
      while (!$feof(fh2) && scan_ok2 == 5) begin
        scan_ok2 = $fscanf(fh2, "%d %d %d %d %d\n", length, base0, zeta0, base1, zeta1);
        if (scan_ok2 == 5) begin
          run_one_level(length, base0, zeta0, base1, zeta1, length);
          lines_read++;
        end
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

  // --- SHA3-512 (G-funktio) ---
  logic sha3_start, sha3_done;
  logic [8*72-1:0] sha3_msg_in;
  logic [511:0] sha3_out;
  pqc_sha3_512 #(.MAX_BLOCKS(1)) sha3_dut (
    .clk(clk), .reset(reset), .start(sha3_start),
    .msg_in(sha3_msg_in), .msg_len_bytes(16'd33),
    .digest_out(sha3_out), .done(sha3_done)
  );

  // --- SampleNTT (A-matriisin generointi) ---
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

  // --- PRF+SamplePolyCBD (eta1 ja eta2, kaksi erillista instanssia) ---
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

  // --- MultiplyNTTs + polyadd + polysub + final_scale ---
  logic [256*COEFF_W-1:0] mntt_f, mntt_g, mntt_h;
  pqc_multiplyntts #(.COEFF_W(COEFF_W)) mntt_dut (.f_hat(mntt_f), .g_hat(mntt_g), .h_hat(mntt_h));
  logic [256*COEFF_W-1:0] padd_a, padd_b, padd_sum;
  pqc_polyadd #(.COEFF_W(COEFF_W)) padd_dut (.a_in(padd_a), .b_in(padd_b), .sum_out(padd_sum));
  logic [256*COEFF_W-1:0] psub_a, psub_b, psub_diff;
  pqc_polysub #(.COEFF_W(COEFF_W)) psub_dut (.a_in(psub_a), .b_in(psub_b), .diff_out(psub_diff));
  logic [256*COEFF_W-1:0] scale_in, scale_out;
  pqc_ntt_final_scale #(.COEFF_W(COEFF_W)) scale_dut (.f_in(scale_in), .f_out(scale_out));

  // --- Compress/Decompress + ByteEncode/Decode (K=2 kutakin) ---
  logic [256*12-1:0] benc12_in [0:1];
  logic [256*12-1:0] benc12_out [0:1];
  pqc_byteencode_dparam #(.D(12)) benc12_0 (.f_in(benc12_in[0]), .b_out(benc12_out[0]));
  pqc_byteencode_dparam #(.D(12)) benc12_1 (.f_in(benc12_in[1]), .b_out(benc12_out[1]));

  logic [256*12-1:0] bdec12_in [0:1];
  logic [256*12-1:0] bdec12_out [0:1];
  pqc_bytedecode_dparam #(.D(12)) bdec12_0 (.b_in(bdec12_in[0]), .f_out(bdec12_out[0]));
  pqc_bytedecode_dparam #(.D(12)) bdec12_1 (.b_in(bdec12_in[1]), .f_out(bdec12_out[1]));

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

  logic [256*DU-1:0] bdec_u_in [0:1];
  logic [256*DU-1:0] bdec_u_out [0:1];
  pqc_bytedecode_dparam #(.D(DU)) bdecu0 (.b_in(bdec_u_in[0]), .f_out(bdec_u_out[0]));
  pqc_bytedecode_dparam #(.D(DU)) bdecu1 (.b_in(bdec_u_in[1]), .f_out(bdec_u_out[1]));

  logic [256*DV-1:0] bdec_v_in;
  logic [256*DV-1:0] bdec_v_out;
  pqc_bytedecode_dparam #(.D(DV)) bdecv (.b_in(bdec_v_in), .f_out(bdec_v_out));

  logic [256*DU-1:0] decompress_u_in [0:1];
  logic [256*COEFF_W-1:0] decompress_u_out [0:1];
  pqc_batch_decompress #(.D(DU), .COEFF_W(COEFF_W)) bdecompu0 (.y_packed(decompress_u_in[0]), .x_packed(decompress_u_out[0]));
  pqc_batch_decompress #(.D(DU), .COEFF_W(COEFF_W)) bdecompu1 (.y_packed(decompress_u_in[1]), .x_packed(decompress_u_out[1]));

  logic [256*DV-1:0] decompress_v_in;
  logic [256*COEFF_W-1:0] decompress_v_out;
  pqc_batch_decompress #(.D(DV), .COEFF_W(COEFF_W)) bdecompv (.y_packed(decompress_v_in), .x_packed(decompress_v_out));

  logic [255:0] benc1_in;
  logic [255:0] benc1_out;
  pqc_byteencode_d1 benc1_dut (.f_in(benc1_in), .b_out(benc1_out));

  logic [255:0] bdec1_in;
  logic [255:0] bdec1_out;
  pqc_bytedecode_d1 bdec1_dut (.b_in(bdec1_in), .f_out(bdec1_out));

  logic [256*COEFF_W-1:0] compress1_in [0:255];
  // Compress1: kayta pqc_compress suoraan per-kerroin (256 kertaa,
  // silmukassa - sama kuin muissakin taman projektin Compress1-
  // kaytoissa, ei uutta moduulia).
  logic [3:0] c1_d_sel;
  logic [COEFF_W-1:0] c1_x_in, c1_compress_out;
  logic [COEFF_W-1:0] c1_y_in, c1_decompress_out;
  pqc_compress #(.COEFF_W(COEFF_W)) compress1_dut (
    .d(c1_d_sel), .x_in(c1_x_in), .compress_out(c1_compress_out),
    .y_in(c1_y_in), .decompress_out(c1_decompress_out)
  );

  // --- Testivektorit ---
  logic [255:0] d_seed, m_original, r_seed;
  logic [8*800-1:0] ekPKE_expect;
  logic [8*768-1:0] dkPKE_expect;
  logic [8*768-1:0] c_expect;
  logic [255:0] m_decrypted_expect;

  int fh, scan_ok, error_count;
  string tag;

  initial begin
    error_count = 0;
    clk = 0; reset = 1;
    ntt_start = 0; count = 0; pair_dist = 0; mode = 0;
    base_addr_lane0 = 0; base_addr_lane1 = 0; zeta_lane0 = 0; zeta_lane1 = 0;
    sha3_start = 0; samplentt_start = 0; cbd1_start = 0; cbd2_start = 0;

    $readmemh("m2-golden/bank_rom_4banks.memh", bank_rom_tb);
    $readmemh("m2-golden/bank_local_4banks.memh", local_rom_tb);

    fh = $fopen("vectors/kpke_roundtrip_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", d_seed);
    scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", m_original);
    scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", r_seed);
    scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", ekPKE_expect);
    scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", dkPKE_expect);
    scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", c_expect);
    scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", m_decrypted_expect);
    $fclose(fh);

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);

    //================================================================
    // VAIHE 1: KeyGen - d -> ekPKE, dkPKE
    //================================================================
    begin
      logic [255:0] rho, sigma;
      logic [256*COEFF_W-1:0] A [0:K-1][0:K-1];
      logic [256*COEFF_W-1:0] s_vec [0:K-1], e_vec [0:K-1];
      logic [256*COEFF_W-1:0] s_hat [0:K-1], e_hat [0:K-1], t_hat [0:K-1];
      logic [8*800-1:0] ekPKE_got;
      logic [8*768-1:0] dkPKE_got;

      sha3_msg_in = '0;
      sha3_msg_in[255:0] = d_seed;
      sha3_msg_in[263:256] = K[7:0];
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
      sha3_start <= 1'b1; @(posedge clk); sha3_start <= 1'b0;
      while (!sha3_done) @(posedge clk);
      #1;
      rho = sha3_out[255:0];
      sigma = sha3_out[511:256];

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
        int N;
        N = 0;
        for (int i = 0; i < K; i++) begin
          cbd1_seed = sigma; cbd1_n = N[7:0];
          reset = 1; @(posedge clk); reset = 0; @(posedge clk);
          cbd1_start <= 1'b1; @(posedge clk); cbd1_start <= 1'b0;
          while (!cbd1_done) @(posedge clk);
          #1;
          s_vec[i] = cbd1_out;
          N++;
        end
        for (int i = 0; i < K; i++) begin
          cbd1_seed = sigma; cbd1_n = N[7:0];
          reset = 1; @(posedge clk); reset = 0; @(posedge clk);
          cbd1_start <= 1'b1; @(posedge clk); cbd1_start <= 1'b0;
          while (!cbd1_done) @(posedge clk);
          #1;
          e_vec[i] = cbd1_out;
          N++;
        end
      end

      for (int i = 0; i < K; i++) run_forward_ntt(s_vec[i], s_hat[i]);
      for (int i = 0; i < K; i++) run_forward_ntt(e_vec[i], e_hat[i]);

      for (int i = 0; i < K; i++) begin
        logic [256*COEFF_W-1:0] acc;
        acc = '0;
        for (int j = 0; j < K; j++) begin
          mntt_f = A[i][j]; mntt_g = s_hat[j];
          #1;
          padd_a = acc; padd_b = mntt_h;
          #1;
          acc = padd_sum;
        end
        padd_a = acc; padd_b = e_hat[i];
        #1;
        t_hat[i] = padd_sum;
      end

      ekPKE_got = '0;
      for (int i = 0; i < K; i++) begin
        for (int c = 0; c < 256; c++) benc12_in[i][c*12 +: 12] = t_hat[i][c*COEFF_W +: COEFF_W];
        #1;
        ekPKE_got[(i*384)*8 +: 384*8] = benc12_out[i];
      end
      ekPKE_got[(2*384)*8 +: 32*8] = rho;

      dkPKE_got = '0;
      for (int i = 0; i < K; i++) begin
        for (int c = 0; c < 256; c++) benc12_in[i][c*12 +: 12] = s_hat[i][c*COEFF_W +: COEFF_W];
        #1;
        dkPKE_got[(i*384)*8 +: 384*8] = benc12_out[i];
      end

      if (ekPKE_got !== ekPKE_expect) begin
        $display("FAIL KeyGen: ekPKE poikkeaa golden-mallista"); error_count++;
      end else $display("OK KeyGen: ekPKE tasmaa golden-malliin");
      if (dkPKE_got !== dkPKE_expect) begin
        $display("FAIL KeyGen: dkPKE poikkeaa golden-mallista"); error_count++;
      end else $display("OK KeyGen: dkPKE tasmaa golden-malliin");

      //================================================================
      // VAIHE 2: Encrypt - ekPKE + m + r -> c
      //================================================================
      begin
        logic [256*COEFF_W-1:0] y_vec [0:K-1], e1_vec [0:K-1], e2_poly;
        logic [256*COEFF_W-1:0] y_hat [0:K-1];
        logic [256*COEFF_W-1:0] u_vec [0:K-1], v_poly;
        logic [8*768-1:0] c_got;
        int Nenc;

        Nenc = 0;
        for (int i = 0; i < K; i++) begin
          cbd1_seed = r_seed; cbd1_n = Nenc[7:0];
          reset = 1; @(posedge clk); reset = 0; @(posedge clk);
          cbd1_start <= 1'b1; @(posedge clk); cbd1_start <= 1'b0;
          while (!cbd1_done) @(posedge clk);
          #1;
          y_vec[i] = cbd1_out;
          Nenc++;
        end
        for (int i = 0; i < K; i++) begin
          cbd2_seed = r_seed; cbd2_n = Nenc[7:0];
          reset = 1; @(posedge clk); reset = 0; @(posedge clk);
          cbd2_start <= 1'b1; @(posedge clk); cbd2_start <= 1'b0;
          while (!cbd2_done) @(posedge clk);
          #1;
          e1_vec[i] = cbd2_out;
          Nenc++;
        end
        cbd2_seed = r_seed; cbd2_n = Nenc[7:0];
        reset = 1; @(posedge clk); reset = 0; @(posedge clk);
        cbd2_start <= 1'b1; @(posedge clk); cbd2_start <= 1'b0;
        while (!cbd2_done) @(posedge clk);
        #1;
        e2_poly = cbd2_out;

        for (int i = 0; i < K; i++) run_forward_ntt(y_vec[i], y_hat[i]);

        // u[col] = NTT^-1(sum_j A[j][col]*y_hat[j]) + e1[col]
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

        // v = NTT^-1(sum_j t_hat[j]*y_hat[j]) + e2 + mu
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
          $display("FAIL Encrypt: c poikkeaa golden-mallista"); error_count++;
        end else $display("OK Encrypt: c (ciphertext) tasmaa golden-malliin");

        //================================================================
        // VAIHE 3: Decrypt - dkPKE + c -> m'
        //================================================================
        begin
          logic [256*DU-1:0] c1_bytes [0:K-1];
          logic [256*DV-1:0] c2_bytes;
          logic [256*COEFF_W-1:0] u_prime [0:K-1], v_prime;
          logic [256*COEFF_W-1:0] s_hat_dec [0:K-1];
          logic [256*COEFF_W-1:0] u_hat [0:K-1];
          logic [255:0] m_decrypted;

          c1_bytes[0] = c_got[(0*DU*32)*8 +: DU*32*8];
          c1_bytes[1] = c_got[(1*DU*32)*8 +: DU*32*8];
          c2_bytes    = c_got[(2*DU*32)*8 +: DV*32*8];

          for (int i = 0; i < K; i++) begin
            bdec_u_in[i] = c1_bytes[i];
            #1;
            decompress_u_in[i] = bdec_u_out[i];
            #1;
            u_prime[i] = decompress_u_out[i];
          end
          bdec_v_in = c2_bytes;
          #1;
          decompress_v_in = bdec_v_out;
          #1;
          v_prime = decompress_v_out;

          for (int i = 0; i < K; i++) begin
            bdec12_in[i] = dkPKE_got[(i*384)*8 +: 384*8];
            #1;
            for (int c = 0; c < 256; c++) s_hat_dec[i][c*COEFF_W +: COEFF_W] = {4'b0, bdec12_out[i][c*12 +: 12]};
          end

          for (int i = 0; i < K; i++) run_forward_ntt(u_prime[i], u_hat[i]);

          begin
            logic [256*COEFF_W-1:0] acc, inner, inner_raw, w;
            acc = '0;
            for (int i = 0; i < K; i++) begin
              mntt_f = s_hat_dec[i]; mntt_g = u_hat[i];
              #1;
              padd_a = acc; padd_b = mntt_h;
              #1;
              acc = padd_sum;
            end
            run_inverse_ntt(acc, inner_raw);
            scale_in = inner_raw;
            #1;
            inner = scale_out;
            psub_a = v_prime; psub_b = inner;
            #1;
            w = psub_diff;

            for (int i = 0; i < 256; i++) begin
              c1_d_sel = 4'd1;
              c1_x_in = w[i*COEFF_W +: COEFF_W];
              #1;
              benc1_in[i] = c1_compress_out[0];
            end
            #1;
            m_decrypted = benc1_out;
          end

          if (m_decrypted !== m_decrypted_expect) begin
            $display("FAIL Decrypt: m_decrypted poikkeaa golden-mallin odotukseen"); error_count++;
          end else $display("OK Decrypt: m_decrypted tasmaa golden-mallin odotukseen");

          if (m_decrypted !== m_original) begin
            $display("FAIL PAATARKISTUS: Decrypt(Encrypt(m)) != m !!!"); error_count++;
          end else $display("OK PAATARKISTUS: Decrypt(Encrypt(m)) == m - TAYDELLINEN ROUND-TRIP VAHVISTETTU");
        end
      end
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: Seed->KeyGen->Encrypt->Decrypt->m TAYDELLINEN INTEGRAATIOTESTI lapaisty");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
