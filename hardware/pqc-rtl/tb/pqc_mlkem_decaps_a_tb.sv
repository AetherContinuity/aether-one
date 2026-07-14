// pqc_mlkem_decaps_a_tb.sv
//
// M3 Issue #15 (jatko): Decaps TB A - ensimmainen puolisko
// ML-KEM.Decaps_internal:sta (kayttajan oma pilkkonta segmentointi-
// virheen valttamiseksi). K-PKE.Decrypt(dkPKE,c) -> m', G(m'||h) ->
// (K',r'). Testataan kaikki kolme jaadytettya tapausta (valid,
// byte_corrupted, bit_corrupted).

`timescale 1ns/1ps

module pqc_mlkem_decaps_a_tb;

  localparam int COEFF_W = 16;
  localparam int SPAD_AW = 9;
  localparam int K = 2;
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

  logic sha512_start, sha512_done;
  logic [8*72-1:0] sha512_msg_in;
  logic [511:0] sha512_out;
  pqc_sha3_512 #(.MAX_BLOCKS(1)) sha512_dut (
    .clk(clk), .reset(reset), .start(sha512_start),
    .msg_in(sha512_msg_in), .msg_len_bytes(16'd64),
    .digest_out(sha512_out), .done(sha512_done)
  );

  logic [256*COEFF_W-1:0] mntt_f, mntt_g, mntt_h;
  pqc_multiplyntts #(.COEFF_W(COEFF_W)) mntt_dut (.f_hat(mntt_f), .g_hat(mntt_g), .h_hat(mntt_h));
  logic [256*COEFF_W-1:0] padd_a, padd_b, padd_sum;
  pqc_polyadd #(.COEFF_W(COEFF_W)) padd_dut (.a_in(padd_a), .b_in(padd_b), .sum_out(padd_sum));
  logic [256*COEFF_W-1:0] psub_a, psub_b, psub_diff;
  pqc_polysub #(.COEFF_W(COEFF_W)) psub_dut (.a_in(psub_a), .b_in(psub_b), .diff_out(psub_diff));
  logic [256*COEFF_W-1:0] scale_in, scale_out;
  pqc_ntt_final_scale #(.COEFF_W(COEFF_W)) scale_dut (.f_in(scale_in), .f_out(scale_out));

  logic [256*12-1:0] bdec12_in [0:1];
  logic [256*12-1:0] bdec12_out [0:1];
  pqc_bytedecode_dparam #(.D(12)) bdec12_0 (.b_in(bdec12_in[0]), .f_out(bdec12_out[0]));
  pqc_bytedecode_dparam #(.D(12)) bdec12_1 (.b_in(bdec12_in[1]), .f_out(bdec12_out[1]));

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

  logic [3:0] c1_d_sel;
  logic [COEFF_W-1:0] c1_x_in, c1_compress_out;
  logic [COEFF_W-1:0] c1_y_in, c1_decompress_out;
  pqc_compress #(.COEFF_W(COEFF_W)) compress1_dut (
    .d(c1_d_sel), .x_in(c1_x_in), .compress_out(c1_compress_out),
    .y_in(c1_y_in), .decompress_out(c1_decompress_out)
  );

  logic [8*768-1:0] dkPKE;
  logic [255:0] h_val;
  int fh, scan_ok, error_count, case_count;
  string tag;

  initial begin
    error_count = 0; case_count = 0;
    clk = 0; reset = 1;
    ntt_start = 0; count = 0; pair_dist = 0; mode = 0;
    base_addr_lane0 = 0; base_addr_lane1 = 0; zeta_lane0 = 0; zeta_lane1 = 0;
    sha512_start = 0;

    $readmemh("m2-golden/bank_rom_4banks.memh", bank_rom_tb);
    $readmemh("m2-golden/bank_local_4banks.memh", local_rom_tb);

    fh = $fopen("vectors/mlkem_decaps_a_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", dkPKE);
    scan_ok = $fscanf(fh, "%h\n", h_val);

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);

    for (int tc = 0; tc < 3; tc++) begin
      logic [8*768-1:0] c_variant;
      logic [255:0] m_prime_expect, K_prime_expect, r_prime_expect;
      logic [255:0] m_prime_got;
      logic [256*DU-1:0] c1_bytes [0:K-1];
      logic [256*DV-1:0] c2_bytes;
      logic [256*COEFF_W-1:0] u_prime [0:K-1], v_prime;
      logic [256*COEFF_W-1:0] s_hat_dec [0:K-1];
      logic [256*COEFF_W-1:0] u_hat [0:K-1];
      logic [256*COEFF_W-1:0] acc, inner_raw, inner, w;

      scan_ok = $fscanf(fh, "%s\n", tag);
      scan_ok = $fscanf(fh, "%h\n", c_variant);
      scan_ok = $fscanf(fh, "%h\n", m_prime_expect);
      scan_ok = $fscanf(fh, "%h\n", K_prime_expect);
      scan_ok = $fscanf(fh, "%h\n", r_prime_expect);

      // --- K-PKE.Decrypt(dkPKE, c) -> m' ---
      c1_bytes[0] = c_variant[(0*DU*32)*8 +: DU*32*8];
      c1_bytes[1] = c_variant[(1*DU*32)*8 +: DU*32*8];
      c2_bytes    = c_variant[(2*DU*32)*8 +: DV*32*8];

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
        bdec12_in[i] = dkPKE[(i*384)*8 +: 384*8];
        #1;
        for (int cc = 0; cc < 256; cc++) s_hat_dec[i][cc*COEFF_W +: COEFF_W] = {4'b0, bdec12_out[i][cc*12 +: 12]};
      end

      for (int i = 0; i < K; i++) run_forward_ntt(u_prime[i], u_hat[i]);

      acc = '0;
      for (int i = 0; i < K; i++) begin
        mntt_f = s_hat_dec[i]; mntt_g = u_hat[i];
        #1;
        padd_a = acc; padd_b = mntt_h;
        #1;
        acc = padd_sum;
      end
      run_inverse_ntt(acc, inner_raw);
      scale_in = inner_raw; #1; inner = scale_out;

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
      m_prime_got = benc1_out;

      if (m_prime_got !== m_prime_expect) begin
        $display("FAIL %s: m' poikkeaa golden-mallista", tag);
        error_count++;
      end else $display("OK %s: m' tasmaa golden-malliin", tag);

      // --- G(m'||h) -> (K',r') ---
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
      sha512_msg_in = '0;
      sha512_msg_in[255:0] = m_prime_got;
      sha512_msg_in[511:256] = h_val;
      sha512_start <= 1'b1; @(posedge clk); sha512_start <= 1'b0;
      while (!sha512_done) @(posedge clk);
      #1;
      begin
        logic [255:0] K_prime_got, r_prime_got;
        K_prime_got = sha512_out[255:0];
        r_prime_got = sha512_out[511:256];
        if (K_prime_got !== K_prime_expect) begin
          $display("FAIL %s: K' poikkeaa golden-mallista", tag); error_count++;
        end else $display("OK %s: K' tasmaa golden-malliin", tag);
        if (r_prime_got !== r_prime_expect) begin
          $display("FAIL %s: r' poikkeaa golden-mallista", tag); error_count++;
        end else $display("OK %s: r' tasmaa golden-malliin", tag);
      end

      case_count++;
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
    end
    $fclose(fh);

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: Decaps TB A (m', K', r' kaikille %0d tapaukselle) tasmaa golden-malliin", case_count);
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
