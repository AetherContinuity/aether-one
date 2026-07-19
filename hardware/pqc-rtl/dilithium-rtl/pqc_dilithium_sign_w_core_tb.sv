// M5-DILITHIUM-001 DK6 S3-testi: w = NTT^-1(A_hat@NTT(y))
// todennus dilithium-py:n omaa (A_hat@y_hat).from_ntt()-tulosta
// vasten.

`timescale 1ns/1ps

module pqc_dilithium_sign_w_core_tb;

  localparam int CW = 23;
  localparam int K = 6;
  localparam int L = 5;

  logic clk, reset, start, done;
  logic [K*L*256*CW-1:0] A_hat_in;
  logic [L*256*CW-1:0] y_in_flat;
  logic [K*256*CW-1:0] w_out_flat;

  always #5 clk = ~clk;

  pqc_dilithium_sign_w_core #(.CW(CW), .K(K), .L(L)) dut (
    .clk(clk), .reset(reset), .start(start),
    .A_hat_in(A_hat_in), .y_in_flat(y_in_flat),
    .done(done), .w_out_flat(w_out_flat)
  );

  int fh, scan_ok;
  logic [K*L*256*CW-1:0] A_val;
  logic [L*256*CW-1:0] y_val;
  logic [K*256*CW-1:0] expect_out;

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/sign_w_core_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", A_val);
    scan_ok = $fscanf(fh, "%h\n", y_val);
    scan_ok = $fscanf(fh, "%h\n", expect_out);
    $fclose(fh);

    A_hat_in = A_val; y_in_flat = y_val;

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    begin
      int wait_cycles;
      wait_cycles = 0;
      while (!done && wait_cycles < 100000) begin @(posedge clk); wait_cycles++; end
      if (!done) $display("FAIL: aikakatkaisu (%0d syklia)", wait_cycles);
      else $display("Valmis %0d syklin jalkeen", wait_cycles);
    end

    if (w_out_flat === expect_out) begin
      $display("PASS: w = NTT^-1(A_hat@NTT(y)) tasmaa taydellisesti kaikille %0d polynomille", K);
    end else begin
      int diffs;
      diffs = 0;
      for (int p = 0; p < K; p++) begin
        if (w_out_flat[p*256*CW +: 256*CW] !== expect_out[p*256*CW +: 256*CW]) diffs++;
      end
      $display("FAIL: %0d/%0d polynomia eroaa", diffs, K);
      $fatal(1);
    end

    $display("--------------------------------------------------");
    $finish;
  end

endmodule
