// M5-DILITHIUM-001 DK4-testi: t = NTT^-1(A*NTT(s1)) + s2 -laskennan
// todennus dilithium-py:n omaa tulosta vasten.

`timescale 1ns/1ps

module pqc_dilithium_keygen_core_tb;

  localparam int CW = 23;
  localparam int K = 6;
  localparam int L = 5;

  logic clk, reset, start, done;
  logic [K*L*256*CW-1:0] A_hat_in;
  logic [L*256*8-1:0] s1_in_flat;
  logic [K*256*8-1:0] s2_in_flat;
  logic [K*256*CW-1:0] t_out_flat;

  always #5 clk = ~clk;

  pqc_dilithium_keygen_core #(.CW(CW), .K(K), .L(L)) dut (
    .clk(clk), .reset(reset), .start(start),
    .A_hat_in(A_hat_in), .s1_in_flat(s1_in_flat), .s2_in_flat(s2_in_flat),
    .done(done), .t_out_flat(t_out_flat)
  );

  int fh, scan_ok;
  logic [K*L*256*CW-1:0] A_val;
  logic [L*256*8-1:0] s1_val;
  logic [K*256*8-1:0] s2_val;
  logic [K*256*CW-1:0] t_expect;

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/keygen_core_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", A_val);
    scan_ok = $fscanf(fh, "%h\n", s1_val);
    scan_ok = $fscanf(fh, "%h\n", s2_val);
    scan_ok = $fscanf(fh, "%h\n", t_expect);
    $fclose(fh);

    A_hat_in = A_val; s1_in_flat = s1_val; s2_in_flat = s2_val;

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    begin
      int wait_cycles;
      wait_cycles = 0;
      while (!done && wait_cycles < 150000) begin @(posedge clk); wait_cycles++; end
      if (!done) $display("FAIL: aikakatkaisu (%0d syklia)", wait_cycles);
      else $display("Valmis %0d syklin jalkeen", wait_cycles);
    end

    if (t_out_flat === t_expect) begin
      $display("PASS: t = NTT^-1(A*NTT(s1))+s2 tasmaa taydellisesti kaikille %0d polynomille", K);
    end else begin
      int diffs;
      diffs = 0;
      for (int p = 0; p < K; p++) begin
        if (t_out_flat[p*256*CW +: 256*CW] !== t_expect[p*256*CW +: 256*CW]) diffs++;
      end
      $display("FAIL: %0d/%0d polynomia eroaa", diffs, K);
      $fatal(1);
    end

    $display("--------------------------------------------------");
    $finish;
  end

endmodule
