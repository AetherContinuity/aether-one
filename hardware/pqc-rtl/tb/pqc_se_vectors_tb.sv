// pqc_se_vectors_tb.sv
//
// M3 Issue #15, Kerros 2 (osa 2/3): s- ja e-vektorien generointi,
// k=2, eta1=3. Ajaa pqc_prf_samplepolycbd.sv:aa (Kerros 1) NELJASTI
// (s[0],s[1],e[0],e[1]), N-laskuri jatkuen s:sta e:hen. EI uutta
// RTL:aa - integraatio-orkestrointi jo validoidun moduulin ympärille.

`timescale 1ns/1ps

module pqc_se_vectors_tb;

  localparam int K = 2;
  localparam int ETA1 = 3;

  logic clk, reset, start, done;
  logic [255:0] sigma;
  logic [7:0] counter_n;
  logic [16*256-1:0] f_out;

  pqc_prf_samplepolycbd #(.ETA(ETA1)) dut (
    .clk(clk), .reset(reset), .start(start),
    .seed_s(sigma), .counter_n(counter_n), .f_out(f_out), .done(done)
  );

  always #5 clk = ~clk;

  logic [16*256-1:0] s_vec [0:K-1];
  logic [16*256-1:0] e_vec [0:K-1];
  logic [16*256-1:0] s_expect [0:K-1];
  logic [16*256-1:0] e_expect [0:K-1];

  int fh, scan_ok, error_count;
  string tag;
  int idx_v, n_v;

  initial begin
    error_count = 0;
    clk = 0; reset = 1; start = 0; sigma = '0; counter_n = 0;

    fh = $fopen("vectors/se_vectors_k2.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", sigma);
    for (int k = 0; k < K; k++) begin
      logic [16*256-1:0] tmp;
      scan_ok = $fscanf(fh, "%s %d %d\n", tag, idx_v, n_v);
      scan_ok = $fscanf(fh, "%h\n", tmp);
      s_expect[idx_v] = tmp;
    end
    for (int k = 0; k < K; k++) begin
      logic [16*256-1:0] tmp;
      scan_ok = $fscanf(fh, "%s %d %d\n", tag, idx_v, n_v);
      scan_ok = $fscanf(fh, "%h\n", tmp);
      e_expect[idx_v] = tmp;
    end
    $fclose(fh);

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);

    // s[i] <- SamplePolyCBD(PRF(sigma, N)), N=0,1 (Alg. 13 rivit 8-11)
    for (int i = 0; i < K; i++) begin
      counter_n = i[7:0];
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
      start <= 1'b1; @(posedge clk); start <= 1'b0;
      while (!done) @(posedge clk);
      #1;
      s_vec[i] = f_out;
    end

    // e[i] <- SamplePolyCBD(PRF(sigma, N)), N=2,3 (Alg. 13 rivit 12-15,
    // N JATKUU s:n jalkeen)
    for (int i = 0; i < K; i++) begin
      counter_n = (K + i);
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
      start <= 1'b1; @(posedge clk); start <= 1'b0;
      while (!done) @(posedge clk);
      #1;
      e_vec[i] = f_out;
    end

    for (int i = 0; i < K; i++) begin
      if (s_vec[i] !== s_expect[i]) begin
        $display("FAIL s[%0d]: poikkeaa golden-mallista", i);
        error_count++;
      end else $display("OK s[%0d]: tasmaa golden-malliin", i);
    end
    for (int i = 0; i < K; i++) begin
      if (e_vec[i] !== e_expect[i]) begin
        $display("FAIL e[%0d]: poikkeaa golden-mallista", i);
        error_count++;
      end else $display("OK e[%0d]: tasmaa golden-malliin", i);
    end

    // Tilavuototesti: s[0] != e[0] (eri N, ei pida sekoittua)
    if (s_vec[0] === e_vec[0]) begin
      $display("FAIL: s[0] == e[0] - N-laskuri ei erottele s:aa ja e:ta!");
      error_count++;
    end else $display("OK: s[0] != e[0] - N-laskuri erottelee s:n ja e:n oikein, ei tilavuotoa");

    if (s_vec[0] === s_vec[1]) begin
      $display("FAIL: s[0] == s[1] - N-laskuri ei erottele komponentteja!");
      error_count++;
    end else $display("OK: s[0] != s[1] - komponentit erottuvat oikein");

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: s- ja e-vektorit (k=%0d, eta1=%0d) tasmaavat golden-malliin", K, ETA1);
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
