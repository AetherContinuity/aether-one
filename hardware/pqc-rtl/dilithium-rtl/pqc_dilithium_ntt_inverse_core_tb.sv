// M5-DILITHIUM-001 DK1-testi: koko inverse-NTT:n todennus
// dilithium-py:n omaa from_ntt()-tulosta vasten (round-trip
// NTT->NTT^-1 palauttaa alkuperaisen polynomin).

`timescale 1ns/1ps

module pqc_dilithium_ntt_inverse_core_tb;

  localparam int CW = 23;

  logic clk, reset, start, done;
  logic [256*CW-1:0] coeffs_in, coeffs_out;

  always #5 clk = ~clk;

  pqc_dilithium_ntt_inverse_core dut (
    .clk(clk), .reset(reset), .start(start),
    .coeffs_in(coeffs_in), .done(done), .coeffs_out(coeffs_out)
  );

  int fh, scan_ok;
  logic [256*CW-1:0] expect_out;

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/ntt_inverse_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", coeffs_in);
    scan_ok = $fscanf(fh, "%h\n", expect_out);
    $fclose(fh);

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    begin
      int wait_cycles;
      wait_cycles = 0;
      while (!done && wait_cycles < 20000) begin
        @(posedge clk);
        wait_cycles++;
      end
      if (!done) $display("FAIL: aikakatkaisu (%0d syklia)", wait_cycles);
      else $display("Valmis %0d syklin jalkeen", wait_cycles);
    end

    if (coeffs_out === expect_out) begin
      $display("PASS: koko inverse-NTT tasmaa taydellisesti kaikille 256 kertoimelle");
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
