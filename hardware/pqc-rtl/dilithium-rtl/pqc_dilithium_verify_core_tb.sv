// M5-DILITHIUM-001 DK5-testi: Az_minus_ct1-laskennan todennus
// dilithium-py:n omaa (A_hat@z_hat - t1_hat.scale(c_hat)).from_ntt()
// -tulosta vasten.

`timescale 1ns/1ps

module pqc_dilithium_verify_core_tb;

  localparam int CW = 23;
  localparam int K = 6;
  localparam int L = 5;

  logic clk, reset, start, done;
  logic [K*L*256*CW-1:0] A_hat_in;
  logic [L*256*CW-1:0] z_in_flat;
  logic [K*256*CW-1:0] t1_in_flat;
  logic [256*8-1:0] c_in_flat;
  logic [K*256*CW-1:0] az_minus_ct1_out_flat;

  always #5 clk = ~clk;

  pqc_dilithium_verify_core #(.CW(CW), .K(K), .L(L)) dut (
    .clk(clk), .reset(reset), .start(start),
    .A_hat_in(A_hat_in), .z_in_flat(z_in_flat), .t1_in_flat(t1_in_flat), .c_in_flat(c_in_flat),
    .done(done), .az_minus_ct1_out_flat(az_minus_ct1_out_flat)
  );

  int fh, scan_ok;
  logic [K*L*256*CW-1:0] A_val;
  logic [L*256*CW-1:0] z_val;
  logic [K*256*CW-1:0] t1_val;
  logic [256*8-1:0] c_val;
  logic [K*256*CW-1:0] expect_out;

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/verify_core_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", A_val);
    scan_ok = $fscanf(fh, "%h\n", z_val);
    scan_ok = $fscanf(fh, "%h\n", t1_val);
    scan_ok = $fscanf(fh, "%h\n", c_val);
    scan_ok = $fscanf(fh, "%h\n", expect_out);
    $fclose(fh);

    A_hat_in = A_val; z_in_flat = z_val; t1_in_flat = t1_val; c_in_flat = c_val;

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

    if (az_minus_ct1_out_flat === expect_out) begin
      $display("PASS: Az_minus_ct1 tasmaa taydellisesti kaikille %0d polynomille", K);
    end else begin
      int diffs;
      diffs = 0;
      for (int p = 0; p < K; p++) begin
        if (az_minus_ct1_out_flat[p*256*CW +: 256*CW] !== expect_out[p*256*CW +: 256*CW]) diffs++;
      end
      $display("FAIL: %0d/%0d polynomia eroaa", diffs, K);
      $fatal(1);
    end

    $display("--------------------------------------------------");
    $finish;
  end

endmodule
