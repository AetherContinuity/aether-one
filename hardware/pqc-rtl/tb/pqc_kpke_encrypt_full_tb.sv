// pqc_kpke_encrypt_full_tb.sv
//
// M3 Issue #15 (loppuunsaattaminen): koko K-PKE.Encrypt paasta paahan.
// Yhdistaa u[0], u[1], v (jo erikseen todennettu) + Compress+ByteEncode
// -pakkauksen (Issue #6/#7:n jo validoidut moduulit) - EI uutta
// aritmetiikkaa, vain integraatio-orkestrointi.

`timescale 1ns/1ps

module pqc_kpke_encrypt_full_tb;

  localparam int COEFF_W = 16;
  localparam int SPAD_AW = 9;
  localparam int K = 2;
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

  // --- Compress+ByteEncode pakkaus (Issue #6/#7) ---
  logic [256*DU-1:0] compress_u_out [0:K-1];
  logic [256*COEFF_W-1:0] compress_u_in [0:K-1];
  pqc_batch_compress #(.D(DU), .COEFF_W(COEFF_W)) bcomp_u0 (.x_packed(compress_u_in[0]), .y_packed(compress_u_out[0]));
  pqc_batch_compress #(.D(DU), .COEFF_W(COEFF_W)) bcomp_u1 (.x_packed(compress_u_in[1]), .y_packed(compress_u_out[1]));

  logic [256*DV-1:0] compress_v_out;
  logic [256*COEFF_W-1:0] compress_v_in;
  pqc_batch_compress #(.D(DV), .COEFF_W(COEFF_W)) bcomp_v (.x_packed(compress_v_in), .y_packed(compress_v_out));

  logic [256*DU-1:0] benc_u_in [0:K-1];
  logic [256*DU-1:0] benc_u_out [0:K-1];
  pqc_byteencode_dparam #(.D(DU)) benc_u0 (.f_in(benc_u_in[0]), .b_out(benc_u_out[0]));
  pqc_byteencode_dparam #(.D(DU)) benc_u1 (.f_in(benc_u_in[1]), .b_out(benc_u_out[1]));

  logic [256*DV-1:0] benc_v_in, benc_v_out;
  pqc_byteencode_dparam #(.D(DV)) benc_v (.f_in(benc_v_in), .b_out(benc_v_out));

  // --- Testivektorit ---
  logic [8*800-1:0] ekPKE_raw;
  logic [255:0] m_raw;
  logic [255:0] r_raw;
  logic [256*COEFF_W-1:0] u_expect [0:K-1];
  logic [256*COEFF_W-1:0] v_expect;
  logic [8*768-1:0] c_expect;

  int fh, scan_ok, error_count;
  string tag;

  // --- Golden-arvoista: A, t_hat, y_hat, e1, e2, mu (uudelleenkaytto
  // jo generoiduista tiedostoista Kerros 3/u0/u1/v-vektoreista) ---
  logic [256*COEFF_W-1:0] A_col0 [0:K-1];
  logic [256*COEFF_W-1:0] A_col1 [0:K-1];
  logic [256*COEFF_W-1:0] t_hat_v [0:K-1];
  logic [256*COEFF_W-1:0] y_hat_all [0:K-1];
  logic [256*COEFF_W-1:0] e1_0, e1_1, e2_val, mu_val;
  logic [256*COEFF_W-1:0] skip_val;

  initial begin
    error_count = 0;
    clk = 0; reset = 1; start = 0; count = 0; pair_dist = 0; mode = 0;
    base_addr_lane0 = 0; base_addr_lane1 = 0; zeta_lane0 = 0; zeta_lane1 = 0;

    $readmemh("m2-golden/bank_rom_4banks.memh", bank_rom_tb);
    $readmemh("m2-golden/bank_local_4banks.memh", local_rom_tb);

    // u[0] omat syotteet
    fh = $fopen("vectors/kpke_encrypt_u0_vectors.txt", "r");
    for (int j = 0; j < K; j++) begin
      logic [256*COEFF_W-1:0] tmp;
      scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", tmp);
      A_col0[j] = tmp;
    end
    for (int j = 0; j < K; j++) begin
      logic [256*COEFF_W-1:0] tmp;
      scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", tmp);
      y_hat_all[j] = tmp;
    end
    scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", skip_val);
    scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", e1_0);
    scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", skip_val);
    $fclose(fh);

    // u[1] oma A-sarake + e1[1]
    fh = $fopen("vectors/kpke_encrypt_u1_vectors.txt", "r");
    for (int j = 0; j < K; j++) begin
      logic [256*COEFF_W-1:0] tmp;
      scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", tmp);
      A_col1[j] = tmp;
    end
    for (int j = 0; j < K; j++) begin
      logic [256*COEFF_W-1:0] tmp;
      scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", tmp);
    end
    scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", skip_val);
    scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", e1_1);
    scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", skip_val);
    $fclose(fh);

    // v oma t_hat + e2 + mu
    fh = $fopen("vectors/kpke_encrypt_v_vectors.txt", "r");
    for (int j = 0; j < K; j++) begin
      logic [256*COEFF_W-1:0] tmp;
      scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", tmp);
      t_hat_v[j] = tmp;
    end
    for (int j = 0; j < K; j++) begin
      logic [256*COEFF_W-1:0] tmp;
      scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", tmp);
    end
    scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", skip_val);
    scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", e2_val);
    scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", mu_val);
    scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", skip_val);
    $fclose(fh);

    // Lopullinen odotettu ciphertext
    fh = $fopen("vectors/kpke_encrypt_full_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", ekPKE_raw);
    scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", m_raw);
    scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", r_raw);
    for (int i = 0; i < K; i++) begin
      logic [256*COEFF_W-1:0] tmp;
      scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", tmp);
      u_expect[i] = tmp;
    end
    scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", v_expect);
    scan_ok = $fscanf(fh, "%s\n", tag); scan_ok = $fscanf(fh, "%h\n", c_expect);
    $fclose(fh);

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);

    // --- u[0], u[1]: sum_j A[j][col]*y_hat[j] -> NTT^-1 -> +e1[col] ---
    for (int col = 0; col < K; col++) begin
      logic [256*COEFF_W-1:0] acc, raw, scaled;
      acc = '0;
      for (int j = 0; j < K; j++) begin
        mntt_f = (col == 0) ? A_col0[j] : A_col1[j];
        mntt_g = y_hat_all[j];
        #1;
        padd_a = acc; padd_b = mntt_h;
        #1;
        acc = padd_sum;
      end
      run_inverse_ntt(acc, raw);
      scale_in = raw; #1; scaled = scale_out;
      padd_a = scaled; padd_b = (col == 0) ? e1_0 : e1_1;
      #1;
      if (padd_sum !== u_expect[col]) begin
        $display("FAIL u[%0d]: poikkeaa golden-mallista", col);
        error_count++;
      end else $display("OK u[%0d]: tasmaa golden-malliin", col);
      compress_u_in[col] = padd_sum;
    end

    // --- v: sum_j t_hat[j]*y_hat[j] -> NTT^-1 -> +e2 -> +mu ---
    begin
      logic [256*COEFF_W-1:0] acc, raw, scaled;
      acc = '0;
      for (int j = 0; j < K; j++) begin
        mntt_f = t_hat_v[j];
        mntt_g = y_hat_all[j];
        #1;
        padd_a = acc; padd_b = mntt_h;
        #1;
        acc = padd_sum;
      end
      run_inverse_ntt(acc, raw);
      scale_in = raw; #1; scaled = scale_out;
      padd_a = scaled; padd_b = e2_val;
      #1;
      padd_a = padd_sum; padd_b = mu_val;
      #1;
      if (padd_sum !== v_expect) begin
        $display("FAIL v: poikkeaa golden-mallista");
        error_count++;
      end else $display("OK v: tasmaa golden-malliin");
      compress_v_in = padd_sum;
    end

    // --- Compress + ByteEncode -> c1||c2 ---
    #1;
    benc_u_in[0] = compress_u_out[0];
    benc_u_in[1] = compress_u_out[1];
    benc_v_in = compress_v_out;
    #1;

    begin
      logic [8*768-1:0] c_got;
      c_got = '0;
      c_got[(0*DU*32)*8 +: DU*32*8] = benc_u_out[0];
      c_got[(1*DU*32)*8 +: DU*32*8] = benc_u_out[1];
      c_got[(2*DU*32)*8 +: DV*32*8] = benc_v_out;

      if (c_got !== c_expect) begin
        $display("FAIL c (ciphertext): poikkeaa golden-mallista");
        error_count++;
      end else $display("OK c (koko ciphertext, %0d tavua): tasmaa golden-malliin", 32*(DU*K+DV));
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: KOKO K-PKE.Encrypt (ekPKE+m+r -> c) tasmaa golden-malliin");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
