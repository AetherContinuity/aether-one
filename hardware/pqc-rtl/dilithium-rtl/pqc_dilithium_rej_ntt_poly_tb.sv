// M5-DILITHIUM-001 DK2-testi: RejNTTPoly (ExpandA:n oma polynomin-
// nayttestys) todennus dilithium-py:n omaa rejection_sample_ntt_poly()
// -tulosta vasten.

`timescale 1ns/1ps

module pqc_dilithium_rej_ntt_poly_tb;

  localparam int CW = 23;

  logic clk, reset, start, done, error_exhausted;
  logic [255:0] rho_in;
  logic [7:0] i_in, j_in;
  logic [256*CW-1:0] coeffs_out;

  always #5 clk = ~clk;

  pqc_dilithium_rej_ntt_poly dut (
    .clk(clk), .reset(reset), .start(start),
    .rho_in(rho_in), .i_in(i_in), .j_in(j_in),
    .done(done), .error_exhausted(error_exhausted), .coeffs_out(coeffs_out)
  );

  int fh, scan_ok;
  logic [255:0] rho_val;
  logic [7:0] i_val, j_val;
  logic [256*CW-1:0] expect_out;

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/rej_ntt_poly_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", rho_val);
    scan_ok = $fscanf(fh, "%h\n", i_val);
    scan_ok = $fscanf(fh, "%h\n", j_val);
    scan_ok = $fscanf(fh, "%h\n", expect_out);
    $fclose(fh);

    rho_in = rho_val; i_in = i_val; j_in = j_val;

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

    if (coeffs_out === expect_out) begin
      $display("PASS: RejNTTPoly tasmaa taydellisesti kaikille 256 kertoimelle");
    end else begin
      int diffs;
      diffs = 0;
      for (int i = 0; i < 256; i++) begin
        if (coeffs_out[i*CW+:CW] !== expect_out[i*CW+:CW]) begin
          diffs++;
          if (diffs <= 5) $display("  ERO kerroin %0d: RTL=%0d golden=%0d", i, coeffs_out[i*CW+:CW], expect_out[i*CW+:CW]);
        end
      end
      $display("FAIL: %0d/256 kerrointa eroaa", diffs);
      $fatal(1);
    end

    $display("--------------------------------------------------");
    $finish;
  end

endmodule
