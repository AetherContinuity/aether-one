// M5-DILITHIUM-001: sign_challenge kahdesti PERAKKAIN, ei reset:ia
// valissa.

`timescale 1ns/1ps

module challenge_twice_tb;

  localparam int CW = 23;
  localparam int K = 6;
  localparam int TAU = 49;

  logic clk, reset, start, done;
  logic [K*256*CW-1:0] w_in_flat;
  logic [511:0] mu_in;
  logic [383:0] c_tilde_out;
  logic [256*8-1:0] c_out_flat;

  always #5 clk = ~clk;

  pqc_dilithium_sign_challenge #(.CW(CW), .K(K), .TAU(TAU)) dut (
    .clk(clk), .reset(reset), .start(start),
    .w_in_flat(w_in_flat), .mu_in(mu_in),
    .done(done), .c_tilde_out(c_tilde_out), .c_out_flat(c_out_flat)
  );

  int fh, scan_ok;
  logic [K*256*CW-1:0] w1_val, w2_val;
  logic [511:0] mu1_val, mu2_val;
  logic [383:0] ct1_expect, ct2_expect;
  logic [256*8-1:0] c1_expect, c2_expect;

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/challenge_twice_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", w1_val);
    scan_ok = $fscanf(fh, "%h\n", mu1_val);
    scan_ok = $fscanf(fh, "%h\n", ct1_expect);
    scan_ok = $fscanf(fh, "%h\n", c1_expect);
    scan_ok = $fscanf(fh, "%h\n", w2_val);
    scan_ok = $fscanf(fh, "%h\n", mu2_val);
    scan_ok = $fscanf(fh, "%h\n", ct2_expect);
    scan_ok = $fscanf(fh, "%h\n", c2_expect);
    $fclose(fh);

    repeat (3) @(posedge clk);
    reset = 0;

    w_in_flat = w1_val; mu_in = mu1_val;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;
    wait (done);
    @(posedge clk);
    if (c_tilde_out === ct1_expect && c_out_flat === c1_expect)
      $display("OK: ENSIMMAINEN kutsu tasmaa");
    else
      $display("FAIL: ENSIMMAINEN kutsu EI tasmaa");

    w_in_flat = w2_val; mu_in = mu2_val;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;
    wait (done);
    @(posedge clk);
    if (c_tilde_out === ct2_expect && c_out_flat === c2_expect) begin
      $display("OK: TOINEN kutsu (EI reset:ia valissa) tasmaa");
      $display("PASS: sign_challenge toimii oikein toistetulla kutsulla");
    end else begin
      $display("FAIL: TOINEN kutsu EI tasmaa");
      $display("  c_tilde tasmaa: %0b, c tasmaa: %0b", c_tilde_out===ct2_expect, c_out_flat===c2_expect);
      $display("  TAMA PALJASTAISI 'toisen kutsun' -bugin sign_challenge:ssa");
    end

    $finish;
  end

endmodule
