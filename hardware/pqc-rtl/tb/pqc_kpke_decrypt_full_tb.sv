// pqc_kpke_decrypt_full_tb.sv
//
// M3 Issue #8, Vaihe 4: koko K-PKE.Decrypt paasta paahan, kiintealla
// testiavaimella (k=2, du=10, dv=4 - ML-KEM-512). Yhdistaa KAIKKI
// aiemmin erikseen todennetut vaiheet:
//   Vaihe 1: ByteDecode+Decompress -> u', v'
//   Vaihe 2: NTT(u') + MultiplyNTTs + polyadd -> sum_hat
//   Vaihe 3: NTT^-1 + final_scale -> inner
//   Vaihe 4 (uusi): polysub (w=v'-inner), Compress1, ByteEncode1 -> m
//
// Kayttaa run_one_level:in KORJATTUA count-parametria (ks.
// NTT_INVERSE_DESIGN_NOTE.md §6 - count=64 tasolla 6, ei length).

`timescale 1ns/1ps

module pqc_kpke_decrypt_full_tb;

  localparam int COEFF_W = 16;
  localparam int SPAD_AW = 9;
  localparam int DU = 10;
  localparam int DV = 4;

  logic clk, reset, start, stage_done, bank_conflict_detected;
  logic [7:0] count, pair_dist;
  logic mode;
  logic [SPAD_AW-1:0] base_addr_lane0, base_addr_lane1;
  logic [COEFF_W-1:0] zeta_lane0, zeta_lane1;

  always #5 clk = ~clk;

  pqc_ntt_stage_banked #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW)) ntt_dut (
    .clk(clk), .reset(reset), .start(start), .count(count),
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
      start <= 1'b1;
      @(posedge clk);
      start <= 1'b0;
      c = 0;
      while (!stage_done && c < 3000) begin @(posedge clk); c++; end
    end
  endtask

  task automatic run_forward_ntt();
    int fh2, zeta0, length, base0, base1, zeta1, scan_ok2;
    begin
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
    end
  endtask

  task automatic run_inverse_ntt();
    int fh2, zeta0, length, base0, base1, zeta1, scan_ok2;
    begin
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
    end
  endtask

  // --- Vaihe 1: ciphertextin purku ---
  logic [256*DU-1:0] c1_0, c1_1;
  logic [256*DU-1:0] compressed_u0, compressed_u1;
  logic [256*COEFF_W-1:0] u_prime_0, u_prime_1;
  pqc_bytedecode_dparam #(.D(DU)) dec_u0 (.b_in(c1_0), .f_out(compressed_u0));
  pqc_bytedecode_dparam #(.D(DU)) dec_u1 (.b_in(c1_1), .f_out(compressed_u1));
  pqc_batch_decompress #(.D(DU), .COEFF_W(COEFF_W)) decomp_u0 (.y_packed(compressed_u0), .x_packed(u_prime_0));
  pqc_batch_decompress #(.D(DU), .COEFF_W(COEFF_W)) decomp_u1 (.y_packed(compressed_u1), .x_packed(u_prime_1));

  logic [256*DV-1:0] c2;
  logic [256*DV-1:0] compressed_v;
  logic [256*COEFF_W-1:0] v_prime;
  pqc_bytedecode_dparam #(.D(DV)) dec_v (.b_in(c2), .f_out(compressed_v));
  pqc_batch_decompress #(.D(DV), .COEFF_W(COEFF_W)) decomp_v (.y_packed(compressed_v), .x_packed(v_prime));

  // --- Vaihe 2: NTT + MultiplyNTTs + polyadd ---
  logic [256*COEFF_W-1:0] s_hat_0, s_hat_1;
  logic [256*COEFF_W-1:0] u_hat_0, u_hat_1;
  logic [256*COEFF_W-1:0] partial_0, partial_1;
  logic [256*COEFF_W-1:0] sum_hat;
  pqc_multiplyntts #(.COEFF_W(COEFF_W)) mntt0 (.f_hat(s_hat_0), .g_hat(u_hat_0), .h_hat(partial_0));
  pqc_multiplyntts #(.COEFF_W(COEFF_W)) mntt1 (.f_hat(s_hat_1), .g_hat(u_hat_1), .h_hat(partial_1));
  pqc_polyadd #(.COEFF_W(COEFF_W)) padd (.a_in(partial_0), .b_in(partial_1), .sum_out(sum_hat));

  // --- Vaihe 3: NTT^-1 + final_scale ---
  logic [256*COEFF_W-1:0] inner_raw, inner;
  pqc_ntt_final_scale #(.COEFF_W(COEFF_W)) scale_dut (.f_in(inner_raw), .f_out(inner));

  // --- Vaihe 4: polysub + Compress1 + ByteEncode1 ---
  logic [256*COEFF_W-1:0] w;
  pqc_polysub #(.COEFF_W(COEFF_W)) psub (.a_in(v_prime), .b_in(inner), .diff_out(w));

  logic [255:0] w_compressed;
  pqc_batch_compress #(.D(1), .COEFF_W(COEFF_W)) bcomp (.x_packed(w), .y_packed(w_compressed));

  logic [255:0] m_bytes;
  pqc_byteencode_d1 enc_m (.f_in(w_compressed), .b_out(m_bytes));

  logic [256*COEFF_W-1:0] w_expect;
  logic [255:0] w_compressed_expect;
  logic [255:0] m_bytes_expect;

  int error_count, fh, scan_ok;

  initial begin
    error_count = 0;

    $readmemh("m2-golden/bank_rom_4banks.memh", bank_rom_tb);
    $readmemh("m2-golden/bank_local_4banks.memh", local_rom_tb);

    fh = $fopen("vectors/kpke_stage2_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", s_hat_0);
    scan_ok = $fscanf(fh, "%h\n", s_hat_1);
    $fclose(fh);

    fh = $fopen("vectors/kpke_stage1_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", c1_0);
    scan_ok = $fscanf(fh, "%h\n", c1_1);
    scan_ok = $fscanf(fh, "%h\n", c2);
    $fclose(fh);

    fh = $fopen("vectors/kpke_decrypt_full_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", w_expect);
    scan_ok = $fscanf(fh, "%h\n", w_compressed_expect);
    scan_ok = $fscanf(fh, "%h\n", m_bytes_expect);
    $fclose(fh);

    clk = 0; reset = 1; start = 0; count = 0; pair_dist = 0; mode = 0;
    base_addr_lane0 = 0; base_addr_lane1 = 0; zeta_lane0 = 0; zeta_lane1 = 0;
    repeat (3) @(posedge clk);
    reset = 0;
    repeat (2) @(posedge clk);

    // --- Vaihe 1 (kombinatorinen - u_prime_0/1, v_prime valmiina heti) ---
    #1;

    // --- Vaihe 2: NTT(u_prime[0]), NTT(u_prime[1]) ---
    for (int i = 0; i < 256; i++) write_bank(bank_rom_tb[i], local_rom_tb[i], u_prime_0[i*COEFF_W +: COEFF_W]);
    run_forward_ntt();
    for (int i = 0; i < 256; i++) u_hat_0[i*COEFF_W +: COEFF_W] = read_bank_tb(bank_rom_tb[i], local_rom_tb[i]);

    reset = 1; @(posedge clk); reset = 0; @(posedge clk);
    for (int i = 0; i < 256; i++) write_bank(bank_rom_tb[i], local_rom_tb[i], u_prime_1[i*COEFF_W +: COEFF_W]);
    run_forward_ntt();
    for (int i = 0; i < 256; i++) u_hat_1[i*COEFF_W +: COEFF_W] = read_bank_tb(bank_rom_tb[i], local_rom_tb[i]);

    #1; // MultiplyNTTs + polyadd asettuu (kombinatorinen) -> sum_hat valmis

    // --- Vaihe 3: NTT^-1(sum_hat) + final_scale ---
    reset = 1; @(posedge clk); reset = 0; @(posedge clk);
    for (int i = 0; i < 256; i++) write_bank(bank_rom_tb[i], local_rom_tb[i], sum_hat[i*COEFF_W +: COEFF_W]);
    run_inverse_ntt();
    for (int i = 0; i < 256; i++) inner_raw[i*COEFF_W +: COEFF_W] = read_bank_tb(bank_rom_tb[i], local_rom_tb[i]);

    #1; // final_scale, polysub, Compress1, ByteEncode1 - kaikki kombinatorisia, asettuu heti

    // --- Tarkistus ---
    if (w !== w_expect) begin
      $display("FAIL w: poikkeaa golden-mallista");
      error_count++;
    end else $display("OK: w tasmaa golden-malliin");

    if (w_compressed !== w_compressed_expect) begin
      $display("FAIL w_compressed (Compress1): poikkeaa golden-mallista");
      error_count++;
    end else $display("OK: w_compressed (Compress1) tasmaa golden-malliin");

    if (m_bytes !== m_bytes_expect) begin
      $display("FAIL m (ByteEncode1): %h, odotettu %h", m_bytes, m_bytes_expect);
      error_count++;
    end else $display("OK: m (lopullinen K-PKE.Decrypt-tulos) tasmaa golden-malliin TAYDELLISESTI");

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: koko K-PKE.Decrypt paasta paahan (k=2, du=10, dv=4) tasmaa golden-malliin");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
