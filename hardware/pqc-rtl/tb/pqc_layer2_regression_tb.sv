// pqc_layer2_regression_tb.sv
//
// M3 Issue #15, Kerros 2 -regressio: yhdesta siemenesta d, koko
// K-PKE.KeyGen Algoritmi 13 rivit 1-15 (G(d||k) -> rho,sigma -> A,s,e).
// Yhdistaa KOLME jo erikseen validoitua moduulia (pqc_sha3_512,
// pqc_samplentt, pqc_prf_samplepolycbd) yhdeksi ketjuksi - EI uutta
// RTL:aa, vain integraatio-orkestrointi (kayttajan oma ehdotus).

`timescale 1ns/1ps

module pqc_layer2_regression_tb;

  localparam int K = 2;
  localparam int ETA1 = 3;

  logic clk, reset;
  always #5 clk = ~clk;

  // --- G(d||k) = SHA3-512 ---
  logic sha3_start, sha3_done;
  logic [8*72-1:0] sha3_msg_in;  // MAX_BLOCKS=1 riittaa 33 tavulle
  logic [511:0] G_out;
  pqc_sha3_512 #(.MAX_BLOCKS(1)) sha3_dut (
    .clk(clk), .reset(reset), .start(sha3_start),
    .msg_in(sha3_msg_in), .msg_len_bytes(16'd33),
    .digest_out(G_out), .done(sha3_done)
  );

  // --- SampleNTT (A-matriisi) ---
  logic samplentt_start, samplentt_done, samplentt_err;
  logic [255:0] rho;
  logic [7:0] byte_j, byte_i;
  logic [16*256-1:0] a_hat;
  logic [15:0] acc_cnt, rej_cnt, xof_cnt;
  pqc_samplentt #(.XOF_BYTES(1008)) samplentt_dut (
    .clk(clk), .reset(reset), .start(samplentt_start),
    .rho(rho), .byte_j(byte_j), .byte_i(byte_i),
    .a_hat(a_hat), .accepted_count(acc_cnt), .rejected_count(rej_cnt),
    .xof_bytes_consumed(xof_cnt), .done(samplentt_done), .error_exhausted(samplentt_err)
  );

  // --- PRF+SamplePolyCBD (s,e) ---
  logic cbd_start, cbd_done;
  logic [255:0] sigma;
  logic [7:0] counter_n;
  logic [16*256-1:0] cbd_out;
  pqc_prf_samplepolycbd #(.ETA(ETA1)) cbd_dut (
    .clk(clk), .reset(reset), .start(cbd_start),
    .seed_s(sigma), .counter_n(counter_n), .f_out(cbd_out), .done(cbd_done)
  );

  logic [255:0] d_seed;
  logic [255:0] rho_expect, sigma_expect;
  logic [16*256-1:0] A_expect [0:K-1][0:K-1];
  logic [16*256-1:0] s_expect [0:K-1];
  logic [16*256-1:0] e_expect [0:K-1];
  logic [16*256-1:0] A_got [0:K-1][0:K-1];
  logic [16*256-1:0] s_got [0:K-1];
  logic [16*256-1:0] e_got [0:K-1];

  int fh, scan_ok, error_count;

  initial begin
    error_count = 0;
    clk = 0; reset = 1;
    sha3_start = 0; samplentt_start = 0; cbd_start = 0;
    sha3_msg_in = '0; byte_j = 0; byte_i = 0; sigma = '0; counter_n = 0;

    fh = $fopen("vectors/layer2_regression_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", d_seed);
    scan_ok = $fscanf(fh, "%h\n", rho_expect);
    scan_ok = $fscanf(fh, "%h\n", sigma_expect);
    for (int i = 0; i < K; i++) begin
      for (int j = 0; j < K; j++) begin
        logic [16*256-1:0] tmp;
        scan_ok = $fscanf(fh, "%h\n", tmp);
        A_expect[i][j] = tmp;
      end
    end
    for (int i = 0; i < K; i++) begin
      logic [16*256-1:0] tmp;
      scan_ok = $fscanf(fh, "%h\n", tmp);
      s_expect[i] = tmp;
    end
    for (int i = 0; i < K; i++) begin
      logic [16*256-1:0] tmp;
      scan_ok = $fscanf(fh, "%h\n", tmp);
      e_expect[i] = tmp;
    end
    $fclose(fh);

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);

    // --- Rivi 1: G(d||k) = SHA3-512(d||k) ---
    sha3_msg_in = '0;
    sha3_msg_in[255:0] = d_seed;
    sha3_msg_in[263:256] = K[7:0];
    reset = 1; @(posedge clk); reset = 0; @(posedge clk);
    sha3_start <= 1'b1; @(posedge clk); sha3_start <= 1'b0;
    while (!sha3_done) @(posedge clk);
    #1;
    rho   = G_out[255:0];
    sigma = G_out[511:256];

    if (rho !== rho_expect) begin
      $display("FAIL: rho poikkeaa golden-mallista");
      error_count++;
    end else $display("OK: rho (G(d||k):n eka puolisko) tasmaa golden-malliin");
    if (sigma !== sigma_expect) begin
      $display("FAIL: sigma poikkeaa golden-mallista");
      error_count++;
    end else $display("OK: sigma (G(d||k):n toinen puolisko) tasmaa golden-malliin");

    // --- Rivit 3-7: A-matriisi ---
    for (int i = 0; i < K; i++) begin
      for (int j = 0; j < K; j++) begin
        byte_j = j[7:0];
        byte_i = i[7:0];
        reset = 1; @(posedge clk); reset = 0; @(posedge clk);
        samplentt_start <= 1'b1; @(posedge clk); samplentt_start <= 1'b0;
        while (!samplentt_done) @(posedge clk);
        #1;
        A_got[i][j] = a_hat;
      end
    end

    // --- Rivit 8-15: s,e (N jatkuu) ---
    for (int i = 0; i < K; i++) begin
      counter_n = i[7:0];
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
      cbd_start <= 1'b1; @(posedge clk); cbd_start <= 1'b0;
      while (!cbd_done) @(posedge clk);
      #1;
      s_got[i] = cbd_out;
    end
    for (int i = 0; i < K; i++) begin
      counter_n = (K + i);
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
      cbd_start <= 1'b1; @(posedge clk); cbd_start <= 1'b0;
      while (!cbd_done) @(posedge clk);
      #1;
      e_got[i] = cbd_out;
    end

    for (int i = 0; i < K; i++) begin
      for (int j = 0; j < K; j++) begin
        if (A_got[i][j] !== A_expect[i][j]) begin
          $display("FAIL A[%0d][%0d]", i, j); error_count++;
        end else $display("OK A[%0d][%0d]", i, j);
      end
    end
    for (int i = 0; i < K; i++) begin
      if (s_got[i] !== s_expect[i]) begin $display("FAIL s[%0d]", i); error_count++; end
      else $display("OK s[%0d]", i);
    end
    for (int i = 0; i < K; i++) begin
      if (e_got[i] !== e_expect[i]) begin $display("FAIL e[%0d]", i); error_count++; end
      else $display("OK e[%0d]", i);
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: Kerros 2 -regressio (d -> G -> rho,sigma -> A+s+e, %0d objektia) tasmaa golden-malliin", 2+K*K+2*K);
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
