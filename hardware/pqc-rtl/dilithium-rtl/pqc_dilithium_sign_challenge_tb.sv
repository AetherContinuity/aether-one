// M5-DILITHIUM-001 DK6 S4-testi: Challenge-generointi (w1=HighBits,
// c_tilde, c) todennus dilithium-py:n omaa tulosta vasten.

`timescale 1ns/1ps

module pqc_dilithium_sign_challenge_tb;

  localparam int CW = 23;
  localparam int K = 6;

  logic clk, reset, start, done;
  logic [K*256*CW-1:0] w_in_flat;
  logic [511:0] mu_in;
  logic [383:0] c_tilde_out;
  logic [256*8-1:0] c_out_flat;

  always #5 clk = ~clk;

  pqc_dilithium_sign_challenge #(.CW(CW), .K(K)) dut (
    .clk(clk), .reset(reset), .start(start),
    .w_in_flat(w_in_flat), .mu_in(mu_in),
    .done(done), .c_tilde_out(c_tilde_out), .c_out_flat(c_out_flat)
  );

  int fh, scan_ok;
  logic [K*256*CW-1:0] w_val;
  logic [511:0] mu_val;
  logic [383:0] c_tilde_expect;
  logic [256*8-1:0] c_expect;

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/sign_challenge_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", w_val);
    scan_ok = $fscanf(fh, "%h\n", mu_val);
    scan_ok = $fscanf(fh, "%h\n", c_tilde_expect);
    scan_ok = $fscanf(fh, "%h\n", c_expect);
    $fclose(fh);

    w_in_flat = w_val; mu_in = mu_val;

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

    if (c_tilde_out === c_tilde_expect) $display("OK: c_tilde tasmaa");
    else begin $display("FAIL: c_tilde EI tasmaa. RTL=%h golden=%h", c_tilde_out, c_tilde_expect); end

    if (c_out_flat === c_expect) $display("OK: c tasmaa");
    else $display("FAIL: c EI tasmaa");

    if (c_tilde_out === c_tilde_expect && c_out_flat === c_expect) begin
      $display("--------------------------------------------------");
      $display("PASS: Challenge-generointi tasmaa taydellisesti");
      $display("--------------------------------------------------");
    end else begin
      $display("--------------------------------------------------");
      $display("FAIL: Challenge-generointi EI tasmaa");
      $fatal(1);
    end

    $finish;
  end

endmodule
