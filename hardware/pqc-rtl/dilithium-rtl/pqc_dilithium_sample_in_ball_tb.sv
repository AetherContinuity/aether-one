// M5-DILITHIUM-001 DK5-testi: SampleInBall todennus dilithium-py:n
// omaa sample_in_ball()-tulosta vasten.

`timescale 1ns/1ps

module pqc_dilithium_sample_in_ball_tb;

  logic clk, reset, start, done, error_exhausted;
  logic [383:0] c_tilde_in;
  logic [256*8-1:0] coeffs_out_flat;

  always #5 clk = ~clk;

  pqc_dilithium_sample_in_ball dut (
    .clk(clk), .reset(reset), .start(start),
    .c_tilde_in(c_tilde_in),
    .done(done), .error_exhausted(error_exhausted), .coeffs_out_flat(coeffs_out_flat)
  );

  int fh, scan_ok;
  logic [383:0] c_tilde_val;
  logic [256*8-1:0] expect_out;

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/sample_in_ball_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", c_tilde_val);
    scan_ok = $fscanf(fh, "%h\n", expect_out);
    $fclose(fh);

    c_tilde_in = c_tilde_val;

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    begin
      int wait_cycles;
      wait_cycles = 0;
      while (!done && wait_cycles < 5000) begin @(posedge clk); wait_cycles++; end
      if (!done) $display("FAIL: aikakatkaisu (%0d syklia)", wait_cycles);
      else $display("Valmis %0d syklin jalkeen (error_exhausted=%0b)", wait_cycles, error_exhausted);
    end

    if (coeffs_out_flat === expect_out) begin
      $display("PASS: SampleInBall tasmaa taydellisesti kaikille 256 kertoimelle");
    end else begin
      int diffs;
      diffs = 0;
      for (int i = 0; i < 256; i++) begin
        if (coeffs_out_flat[i*8+:8] !== expect_out[i*8+:8]) begin
          diffs++;
          if (diffs <= 10) $display("  ERO kerroin %0d: RTL=%0d golden=%0d", i, $signed(coeffs_out_flat[i*8+:8]), $signed(expect_out[i*8+:8]));
        end
      end
      $display("FAIL: %0d/256 kerrointa eroaa", diffs);
      $fatal(1);
    end

    $display("--------------------------------------------------");
    $finish;
  end

endmodule
