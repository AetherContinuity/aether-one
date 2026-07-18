// M5-DILITHIUM-001 DK3-testi: RejBoundedPoly (ExpandS:n oma
// polynomin-nayttestys) todennus dilithium-py:n omaa
// rejection_bounded_poly()-tulosta vasten.

`timescale 1ns/1ps

module pqc_dilithium_rej_bounded_poly_tb;

  logic clk, reset, start, done, error_exhausted;
  logic [511:0] rho_prime_in;
  logic [15:0] i_in;
  logic [256*8-1:0] coeffs_out_flat;

  always #5 clk = ~clk;

  pqc_dilithium_rej_bounded_poly dut (
    .clk(clk), .reset(reset), .start(start),
    .rho_prime_in(rho_prime_in), .i_in(i_in),
    .done(done), .error_exhausted(error_exhausted), .coeffs_out_flat(coeffs_out_flat)
  );

  int fh, scan_ok;
  logic [511:0] rho_prime_val;
  logic [15:0] i_val;
  logic [256*8-1:0] expect_out;

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/rej_bounded_poly_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", rho_prime_val);
    scan_ok = $fscanf(fh, "%h\n", i_val);
    scan_ok = $fscanf(fh, "%h\n", expect_out);
    $fclose(fh);

    rho_prime_in = rho_prime_val; i_in = i_val;

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    begin
      int wait_cycles;
      wait_cycles = 0;
      while (!done && wait_cycles < 3000) begin @(posedge clk); wait_cycles++; end
      if (!done) $display("FAIL: aikakatkaisu (%0d syklia)", wait_cycles);
      else $display("Valmis %0d syklin jalkeen (error_exhausted=%0b)", wait_cycles, error_exhausted);
    end

    if (coeffs_out_flat === expect_out) begin
      $display("PASS: RejBoundedPoly tasmaa taydellisesti kaikille 256 kertoimelle");
    end else begin
      int diffs;
      diffs = 0;
      for (int i = 0; i < 256; i++) begin
        if (coeffs_out_flat[i*8+:8] !== expect_out[i*8+:8]) begin
          diffs++;
          if (diffs <= 5) $display("  ERO kerroin %0d: RTL=%0d golden=%0d",
                                     i, $signed(coeffs_out_flat[i*8+:8]), $signed(expect_out[i*8+:8]));
        end
      end
      $display("FAIL: %0d/256 kerrointa eroaa", diffs);
      $fatal(1);
    end

    $display("--------------------------------------------------");
    $finish;
  end

endmodule
