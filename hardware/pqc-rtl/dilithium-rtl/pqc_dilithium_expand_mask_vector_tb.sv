// M5-DILITHIUM-001 DK6 S2-testi: koko y-vektorin (5 polynomia)
// muodostus todennus dilithium-py:n omaa _expand_mask_vector()-
// tulosta vasten.

`timescale 1ns/1ps

module pqc_dilithium_expand_mask_vector_tb;

  localparam int ZW = 24;
  localparam int L = 5;

  logic clk, reset, start, done;
  logic [511:0] rho_prime_in;
  logic [15:0] kappa_in;
  logic [L*256*ZW-1:0] y_out_flat;

  always #5 clk = ~clk;

  pqc_dilithium_expand_mask_vector #(.ZW(ZW), .L(L)) dut (
    .clk(clk), .reset(reset), .start(start),
    .rho_prime_in(rho_prime_in), .kappa_in(kappa_in),
    .done(done), .y_out_flat(y_out_flat)
  );

  int fh, scan_ok;
  logic [511:0] rho_prime_val;
  logic [15:0] kappa_val;
  logic [L*256*ZW-1:0] expect_out;

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/expand_mask_vector_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", rho_prime_val);
    scan_ok = $fscanf(fh, "%h\n", kappa_val);
    scan_ok = $fscanf(fh, "%h\n", expect_out);
    $fclose(fh);

    rho_prime_in = rho_prime_val; kappa_in = kappa_val;

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    begin
      int wait_cycles;
      wait_cycles = 0;
      while (!done && wait_cycles < 10000) begin @(posedge clk); wait_cycles++; end
      if (!done) $display("FAIL: aikakatkaisu (%0d syklia)", wait_cycles);
      else $display("Valmis %0d syklin jalkeen", wait_cycles);
    end

    if (y_out_flat === expect_out) begin
      $display("PASS: koko y-vektori (5 polynomia) tasmaa taydellisesti");
    end else begin
      int diffs;
      diffs = 0;
      for (int i = 0; i < L*256; i++) begin
        if (y_out_flat[i*ZW+:ZW] !== expect_out[i*ZW+:ZW]) diffs++;
      end
      $display("FAIL: %0d/%0d kerrointa eroaa", diffs, L*256);
      $fatal(1);
    end

    $display("--------------------------------------------------");
    $finish;
  end

endmodule
