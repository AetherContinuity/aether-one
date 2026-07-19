// M5-DILITHIUM-001 DK6 S1-testi: ExpandMask (yksi polynomi)
// todennus dilithium-py:n omaa sample_mask_polynomial()-tulosta
// vasten.

`timescale 1ns/1ps

module pqc_dilithium_expand_mask_poly_tb;

  localparam int ZW = 24;

  logic clk, reset, start, done;
  logic [511:0] rho_prime_in;
  logic [15:0] kappa_plus_i_in;
  logic [256*ZW-1:0] y_out_flat;

  always #5 clk = ~clk;

  pqc_dilithium_expand_mask_poly #(.ZW(ZW)) dut (
    .clk(clk), .reset(reset), .start(start),
    .rho_prime_in(rho_prime_in), .kappa_plus_i_in(kappa_plus_i_in),
    .done(done), .y_out_flat(y_out_flat)
  );

  int fh, scan_ok;
  logic [511:0] rho_prime_val;
  logic [15:0] kappa_i_val;
  logic [256*ZW-1:0] expect_out;

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/expand_mask_poly_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", rho_prime_val);
    scan_ok = $fscanf(fh, "%h\n", kappa_i_val);
    scan_ok = $fscanf(fh, "%h\n", expect_out);
    $fclose(fh);

    rho_prime_in = rho_prime_val; kappa_plus_i_in = kappa_i_val;

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
      else $display("Valmis %0d syklin jalkeen", wait_cycles);
    end

    if (y_out_flat === expect_out) begin
      $display("PASS: ExpandMask (yksi polynomi) tasmaa taydellisesti");
    end else begin
      int diffs;
      diffs = 0;
      for (int i = 0; i < 256; i++) begin
        if (y_out_flat[i*ZW+:ZW] !== expect_out[i*ZW+:ZW]) begin
          diffs++;
          if (diffs <= 5) $display("  ERO kerroin %0d: RTL=%0d golden=%0d", i, $signed(y_out_flat[i*ZW+:ZW]), $signed(expect_out[i*ZW+:ZW]));
        end
      end
      $display("FAIL: %0d/256 kerrointa eroaa", diffs);
      $fatal(1);
    end

    $display("--------------------------------------------------");
    $finish;
  end

endmodule
