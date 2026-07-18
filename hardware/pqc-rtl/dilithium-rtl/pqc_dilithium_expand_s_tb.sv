// M5-DILITHIUM-001 DK3-testi: koko s1/s2-vektoreiden (11 polynomia)
// todennus dilithium-py:n omaa _expand_vector_from_seed()-tulosta
// vasten.

`timescale 1ns/1ps

module pqc_dilithium_expand_s_tb;

  localparam int K = 6;
  localparam int L = 5;

  logic clk, reset, start, done;
  logic [511:0] rho_prime_in;
  logic [L*256*8-1:0] s1_out_flat;
  logic [K*256*8-1:0] s2_out_flat;

  always #5 clk = ~clk;

  pqc_dilithium_expand_s #(.K(K), .L(L)) dut (
    .clk(clk), .reset(reset), .start(start),
    .rho_prime_in(rho_prime_in), .done(done),
    .s1_out_flat(s1_out_flat), .s2_out_flat(s2_out_flat)
  );

  int fh, scan_ok, error_count;
  logic [511:0] rho_prime_val;
  logic [L*256*8-1:0] s1_expect;
  logic [K*256*8-1:0] s2_expect;

  initial begin
    error_count = 0;
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/expand_s_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", rho_prime_val);
    scan_ok = $fscanf(fh, "%h\n", s1_expect);
    scan_ok = $fscanf(fh, "%h\n", s2_expect);
    $fclose(fh);

    rho_prime_in = rho_prime_val;

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

    if (s1_out_flat === s1_expect) $display("OK: s1 (5 polynomia) tasmaa taydellisesti");
    else begin $display("FAIL: s1 EI tasmaa"); error_count++; end

    if (s2_out_flat === s2_expect) $display("OK: s2 (6 polynomia) tasmaa taydellisesti");
    else begin $display("FAIL: s2 EI tasmaa"); error_count++; end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: koko s1+s2 (11 polynomia) tasmaa taydellisesti");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
