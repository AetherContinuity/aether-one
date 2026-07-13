// pqc_kpke_encrypt_v_tb.sv
//
// M3 Issue #15 (jatko), K-PKE.Encrypt Vaihe 1: v = NTT^-1(sum_j
// A[j][0]*y_hat[j]) + e1[0]. HUOM: A[j][0] - TRANSPONOITU indeksointi
// (sarake 0, ei rivi 0) - sama A-matriisi kuin KeyGenissa, vain
// LUKUJARJESTYS eri. Ei mitaan "transponoitua A:ta" tallenneta -
// orkestrointi vain vaihtaa indeksien kayttojarjestysta.
//
// Kayttaa jo validoituja moduuleita: pqc_ntt_stage_banked (mode=0
// JA mode=1, molemmat suunnat), pqc_ntt_final_scale, pqc_multiplyntts,
// pqc_polyadd. EI uutta aritmetiikkaa.

`timescale 1ns/1ps

module pqc_kpke_encrypt_v_tb;

  localparam int COEFF_W = 16;
  localparam int SPAD_AW = 9;
  localparam int K = 2;

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
      start <= 1'b1;
      @(posedge clk);
      start <= 1'b0;
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

  logic [256*COEFF_W-1:0] mntt_f, mntt_g, mntt_h;
  pqc_multiplyntts #(.COEFF_W(COEFF_W)) mntt_dut (.f_hat(mntt_f), .g_hat(mntt_g), .h_hat(mntt_h));

  logic [256*COEFF_W-1:0] padd_a, padd_b, padd_sum;
  pqc_polyadd #(.COEFF_W(COEFF_W)) padd_dut (.a_in(padd_a), .b_in(padd_b), .sum_out(padd_sum));

  logic [256*COEFF_W-1:0] scale_in, scale_out;
  pqc_ntt_final_scale #(.COEFF_W(COEFF_W)) scale_dut (.f_in(scale_in), .f_out(scale_out));

  logic [256*COEFF_W-1:0] t_hat_v [0:K-1];
  logic [256*COEFF_W-1:0] e2_val;
  logic [256*COEFF_W-1:0] mu_val;

  logic [256*COEFF_W-1:0] y_hat_expect [0:K-1];
  logic [256*COEFF_W-1:0] sum_before_e2_expect;
  logic [256*COEFF_W-1:0] v_expect;
  logic [256*COEFF_W-1:0] acc;
  logic [256*COEFF_W-1:0] ntt_inv_raw, ntt_inv_scaled;
  logic [256*COEFF_W-1:0] v_got;

  int fh, scan_ok, error_count;
  string tag;

  initial begin
    error_count = 0;
    clk = 0; reset = 1; start = 0; count = 0; pair_dist = 0; mode = 0;
    base_addr_lane0 = 0; base_addr_lane1 = 0; zeta_lane0 = 0; zeta_lane1 = 0;

    $readmemh("m2-golden/bank_rom_4banks.memh", bank_rom_tb);
    $readmemh("m2-golden/bank_local_4banks.memh", local_rom_tb);

    fh = $fopen("vectors/kpke_encrypt_v_vectors.txt", "r");
    for (int j = 0; j < K; j++) begin
      logic [256*COEFF_W-1:0] tmp;
      scan_ok = $fscanf(fh, "%s\n", tag);
      scan_ok = $fscanf(fh, "%h\n", tmp);
      t_hat_v[j] = tmp;
    end
    for (int j = 0; j < K; j++) begin
      logic [256*COEFF_W-1:0] tmp;
      scan_ok = $fscanf(fh, "%s\n", tag);
      scan_ok = $fscanf(fh, "%h\n", tmp);
      y_hat_expect[j] = tmp;
    end
    scan_ok = $fscanf(fh, "%s\n", tag);
    scan_ok = $fscanf(fh, "%h\n", sum_before_e2_expect);
    scan_ok = $fscanf(fh, "%s\n", tag);
    scan_ok = $fscanf(fh, "%h\n", e2_val);
    scan_ok = $fscanf(fh, "%s\n", tag);
    scan_ok = $fscanf(fh, "%h\n", mu_val);
    scan_ok = $fscanf(fh, "%s\n", tag);
    scan_ok = $fscanf(fh, "%h\n", v_expect);
    $fclose(fh);

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);

    // --- sum = sum_j t_hat[j] * y_hat[j] (pistetulo, EI transponoitu) ---
    acc = '0;
    for (int j = 0; j < K; j++) begin
      mntt_f = t_hat_v[j];
      mntt_g = y_hat_expect[j];
      #1;
      padd_a = acc;
      padd_b = mntt_h;
      #1;
      acc = padd_sum;
    end

    if (acc !== sum_before_e2_expect) begin
      $display("FAIL sum_before_e2: poikkeaa golden-mallista");
      error_count++;
    end else $display("OK sum_before_e2 = sum_j t_hat[j]*y_hat[j]: tasmaa golden-malliin");

    // --- NTT^-1(sum) + e2 + mu ---
    run_inverse_ntt(acc, ntt_inv_raw);
    scale_in = ntt_inv_raw;
    #1;
    ntt_inv_scaled = scale_out;

    padd_a = ntt_inv_scaled;
    padd_b = e2_val;
    #1;
    padd_a = padd_sum;
    padd_b = mu_val;
    #1;
    v_got = padd_sum;

    if (v_got !== v_expect) begin
      $display("FAIL v: poikkeaa golden-mallista");
      error_count++;
    end else $display("OK v = NTT^-1(sum) + e2 + mu: tasmaa golden-malliin (LOPULLINEN)");

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: v (pistetulo t_hat^T.y_hat + e2 + mu) tasmaa golden-malliin");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
