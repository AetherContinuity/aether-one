// M5-DILITHIUM-001 DK2-testi: koko A-matriisin (30 polynomia)
// todennus dilithium-py:n omaa _generate_matrix_from_seed()-tulosta
// vasten.

`timescale 1ns/1ps

module pqc_dilithium_expand_a_tb;

  localparam int CW = 23;
  localparam int K = 6;
  localparam int L = 5;

  logic clk, reset, start, done;
  logic [255:0] rho_in;
  logic [K*L*256*CW-1:0] A_out_flat;

  always #5 clk = ~clk;

  pqc_dilithium_expand_a #(.CW(CW), .K(K), .L(L)) dut (
    .clk(clk), .reset(reset), .start(start),
    .rho_in(rho_in), .done(done), .A_out_flat(A_out_flat)
  );

  int fh, scan_ok, error_count;
  logic [255:0] rho_val;
  logic [K*L*256*CW-1:0] expect_out;

  initial begin
    error_count = 0;
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/expand_a_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", rho_val);
    scan_ok = $fscanf(fh, "%h\n", expect_out);
    $fclose(fh);

    rho_in = rho_val;

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    begin
      int wait_cycles;
      wait_cycles = 0;
      while (!done && wait_cycles < 20000) begin @(posedge clk); wait_cycles++; end
      if (!done) $display("FAIL: aikakatkaisu (%0d syklia)", wait_cycles);
      else $display("Valmis %0d syklin jalkeen", wait_cycles);
    end

    if (A_out_flat === expect_out) begin
      $display("PASS: koko A-matriisi (30 polynomia) tasmaa taydellisesti");
    end else begin
      int diffs;
      diffs = 0;
      for (int p = 0; p < K*L; p++) begin
        if (A_out_flat[p*256*CW +: 256*CW] !== expect_out[p*256*CW +: 256*CW]) begin
          diffs++;
          if (diffs <= 5) $display("  ERO polynomi %0d (i=%0d,j=%0d)", p, p/L, p%L);
        end
      end
      $display("FAIL: %0d/%0d polynomia eroaa", diffs, K*L);
      $fatal(1);
    end

    $display("--------------------------------------------------");
    $finish;
  end

endmodule
