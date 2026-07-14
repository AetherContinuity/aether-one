// pqc_kpke_keygen_t_tb.sv
//
// M3 Issue #15, Kerros 3 (osa 1): t_hat = A.s_hat + e_hat laskenta,
// jaljittaen JOKAINEN valivaihe golden-malliin (kayttajan oma ohje).
// HUOM: t_hat pysyy KOKONAAN NTT-alueessa, EI NTT^-1:ta tarvita
// (tarkennettu kayttajan omaan hahmotelmaan - ks. design-kommentti).
//
// Kayttaa jo validoituja moduuleita: pqc_ntt_stage_banked (M2),
// pqc_multiplyntts (Issue #8 esityo), pqc_polyadd (Issue #8). EI
// uutta aritmetiikkaa - vain integraatio-orkestrointi.

`timescale 1ns/1ps

module pqc_kpke_keygen_t_tb;

  localparam int COEFF_W = 16;
  localparam int SPAD_AW = 9;
  localparam int K = 2;

  // --- NTT-ajuri (sama kuin Issue #8:n oma pattern) ---
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

  task automatic run_forward_ntt(input logic [256*COEFF_W-1:0] poly_in,
                                   output logic [256*COEFF_W-1:0] poly_out);
    int fh2, length, base0, zeta0, base1, zeta1, scan_ok2;
    int c;
    begin
      for (int i = 0; i < 256; i++) write_bank(bank_rom_tb[i], local_rom_tb[i], poly_in[i*COEFF_W +: COEFF_W]);
      mode <= 1'b0;

      fh2 = $fopen("vectors/full_level6_zeta.txt", "r");
      scan_ok2 = $fscanf(fh2, "%d\n", zeta0);
      $fclose(fh2);
      pair_dist       <= 8'd128;
      base_addr_lane0 <= 9'd0;
      base_addr_lane1 <= 9'd64;
      zeta_lane0      <= zeta0[15:0];
      zeta_lane1      <= zeta0[15:0];
      count           <= 8'd64;
      @(posedge clk);
      start <= 1'b1;
      @(posedge clk);
      start <= 1'b0;
      c = 0;
      while (!stage_done && c < 3000) begin @(posedge clk); c++; end

      fh2 = $fopen("vectors/full_schedule.txt", "r");
      scan_ok2 = 5;
      while (!$feof(fh2) && scan_ok2 == 5) begin
        scan_ok2 = $fscanf(fh2, "%d %d %d %d %d\n", length, base0, zeta0, base1, zeta1);
        if (scan_ok2 == 5) begin
          pair_dist       <= 8'(length);
          base_addr_lane0 <= 9'(base0);
          base_addr_lane1 <= 9'(base1);
          zeta_lane0      <= zeta0[15:0];
          zeta_lane1      <= zeta1[15:0];
          count           <= 8'(length);
          @(posedge clk);
          start <= 1'b1;
          @(posedge clk);
          start <= 1'b0;
          c = 0;
          while (!stage_done && c < 3000) begin @(posedge clk); c++; end
        end
      end
      $fclose(fh2);

      for (int i = 0; i < 256; i++) poly_out[i*COEFF_W +: COEFF_W] = read_bank_tb(bank_rom_tb[i], local_rom_tb[i]);
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
    end
  endtask

  // --- MultiplyNTTs + polyadd ---
  logic [256*COEFF_W-1:0] mntt_f, mntt_g, mntt_h;
  pqc_multiplyntts #(.COEFF_W(COEFF_W)) mntt_dut (.f_hat(mntt_f), .g_hat(mntt_g), .h_hat(mntt_h));

  logic [256*COEFF_W-1:0] padd_a, padd_b, padd_sum;
  pqc_polyadd #(.COEFF_W(COEFF_W)) padd_dut (.a_in(padd_a), .b_in(padd_b), .sum_out(padd_sum));

  // --- Syotteet (s,e,A jo generoitu erikseen Kerros 2:ssa - luetaan
  // suoraan aiemmasta vektoritiedostosta uudelleenkaytettavaksi) ---
  logic [256*COEFF_W-1:0] s_vec [0:K-1];
  logic [256*COEFF_W-1:0] e_vec [0:K-1];
  logic [256*COEFF_W-1:0] A_mat [0:K-1][0:K-1];

  logic [256*COEFF_W-1:0] s_hat [0:K-1];
  logic [256*COEFF_W-1:0] e_hat [0:K-1];
  logic [256*COEFF_W-1:0] t_hat [0:K-1];

  logic [256*COEFF_W-1:0] s_hat_expect [0:K-1];
  logic [256*COEFF_W-1:0] e_hat_expect [0:K-1];
  logic [256*COEFF_W-1:0] t_hat_expect [0:K-1];
  logic [256*COEFF_W-1:0] product_t0_expect [0:K-1];
  logic [256*COEFF_W-1:0] sum_before_e_t0_expect;

  int fh, scan_ok, error_count;
  string tag;
  int idx_v;
  int n_unused;

  initial begin
    error_count = 0;
    clk = 0; reset = 1; start = 0; count = 0; pair_dist = 0; mode = 0;
    base_addr_lane0 = 0; base_addr_lane1 = 0; zeta_lane0 = 0; zeta_lane1 = 0;

    $readmemh("m2-golden/bank_rom_4banks.memh", bank_rom_tb);
    $readmemh("m2-golden/bank_local_4banks.memh", local_rom_tb);

    // Lue KAIKKI (A, s, e, s_hat, e_hat, t_hat, valivaiheet) YHDESTA
    // johdonmukaisesta tiedostosta - sama d-siemen kaikkialla. KORJATTU:
    // aiempi versio luki s/e/A eri tiedostoista jotka kayttivat ERI
    // sigma/rho-arvoja kuin tama t_hat-laskenta (gen_se_vectors.py kaytti
    // kiinteaa, d-siemenesta riippumatonta sigma:aa) - EI RTL-bugi, vaan
    // vektorigeneraattoreiden keskinainen epajohdonmukaisuus, loydetty
    // ja korjattu (gen_kpke_keygen_t_vectors.py vie nyt A/s/e:n itse).
    fh = $fopen("vectors/kpke_keygen_t_vectors.txt", "r");
    for (int n = 0; n < K*K; n++) begin
      int iv, jv;
      logic [256*COEFF_W-1:0] tmp;
      scan_ok = $fscanf(fh, "%s %d %d\n", tag, iv, jv);
      scan_ok = $fscanf(fh, "%h\n", tmp);
      A_mat[iv][jv] = tmp;
    end
    for (int k = 0; k < K; k++) begin
      logic [256*COEFF_W-1:0] tmp;
      scan_ok = $fscanf(fh, "%s %d\n", tag, idx_v);
      scan_ok = $fscanf(fh, "%h\n", tmp);
      s_vec[idx_v] = tmp;
    end
    for (int k = 0; k < K; k++) begin
      logic [256*COEFF_W-1:0] tmp;
      scan_ok = $fscanf(fh, "%s %d\n", tag, idx_v);
      scan_ok = $fscanf(fh, "%h\n", tmp);
      e_vec[idx_v] = tmp;
    end
    for (int k = 0; k < K; k++) begin
      logic [256*COEFF_W-1:0] tmp;
      scan_ok = $fscanf(fh, "%s %d\n", tag, idx_v);
      scan_ok = $fscanf(fh, "%h\n", tmp);
      s_hat_expect[idx_v] = tmp;
    end
    for (int k = 0; k < K; k++) begin
      logic [256*COEFF_W-1:0] tmp;
      scan_ok = $fscanf(fh, "%s %d\n", tag, idx_v);
      scan_ok = $fscanf(fh, "%h\n", tmp);
      e_hat_expect[idx_v] = tmp;
    end
    for (int k = 0; k < K; k++) begin
      logic [256*COEFF_W-1:0] tmp;
      scan_ok = $fscanf(fh, "%s %d\n", tag, idx_v);
      scan_ok = $fscanf(fh, "%h\n", tmp);
      t_hat_expect[idx_v] = tmp;
    end
    for (int j = 0; j < K; j++) begin
      logic [256*COEFF_W-1:0] tmp;
      scan_ok = $fscanf(fh, "%s\n", tag);
      scan_ok = $fscanf(fh, "%h\n", tmp);
      product_t0_expect[j] = tmp;
    end
    begin
      logic [256*COEFF_W-1:0] tmp;
      scan_ok = $fscanf(fh, "%s\n", tag);
      scan_ok = $fscanf(fh, "%h\n", tmp);
      sum_before_e_t0_expect = tmp;
    end
    $fclose(fh);

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);

    // --- Rivi 16: s_hat = NTT(s) ---
    for (int i = 0; i < K; i++) begin
      run_forward_ntt(s_vec[i], s_hat[i]);
      if (s_hat[i] !== s_hat_expect[i]) begin
        $display("FAIL s_hat[%0d]: poikkeaa golden-mallista (DATAMUOTOTESTI: onko NTT ajettu oikein?)", i);
        error_count++;
      end else $display("OK s_hat[%0d] = NTT(s[%0d]): tasmaa golden-malliin", i, i);
    end

    // --- Rivi 17: e_hat = NTT(e) ---
    for (int i = 0; i < K; i++) begin
      run_forward_ntt(e_vec[i], e_hat[i]);
      if (e_hat[i] !== e_hat_expect[i]) begin
        $display("FAIL e_hat[%0d]: poikkeaa golden-mallista", i);
        error_count++;
      end else $display("OK e_hat[%0d] = NTT(e[%0d]): tasmaa golden-malliin", i, i);
    end

    // --- Rivi 18: t_hat[i] = sum_j MultiplyNTTs(A[i][j], s_hat[j]) + e_hat[i] ---
    for (int i = 0; i < K; i++) begin
      logic [256*COEFF_W-1:0] acc;
      acc = '0;
      for (int j = 0; j < K; j++) begin
        mntt_f = A_mat[i][j];
        mntt_g = s_hat[j];
        #1;
        if (i == 0) begin
          if (mntt_h !== product_t0_expect[j]) begin
            $display("FAIL product_t0_%0d (A[0][%0d]*s_hat[%0d]): poikkeaa golden-mallista", j, j, j);
            error_count++;
          end else $display("OK product_t0_%0d = MultiplyNTTs(A[0][%0d], s_hat[%0d]): tasmaa golden-malliin", j, j, j);
        end
        padd_a = acc;
        padd_b = mntt_h;
        #1;
        acc = padd_sum;
      end
      if (i == 0) begin
        if (acc !== sum_before_e_t0_expect) begin
          $display("FAIL sum_before_e (t[0]): poikkeaa golden-mallista");
          error_count++;
        end else $display("OK sum_before_e (t[0]) = sum_j MultiplyNTTs(A[0][j],s_hat[j]): tasmaa golden-malliin");
      end
      padd_a = acc;
      padd_b = e_hat[i];
      #1;
      t_hat[i] = padd_sum;
      if (t_hat[i] !== t_hat_expect[i]) begin
        $display("FAIL t_hat[%0d]: poikkeaa golden-mallista", i);
        error_count++;
      end else $display("OK t_hat[%0d] = sum + e_hat[%0d]: tasmaa golden-malliin (LOPULLINEN)", i, i);
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: t_hat = A.s_hat + e_hat (k=%0d, jokainen valivaihe jaljitetty) tasmaa golden-malliin", K);
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
