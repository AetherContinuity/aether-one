// M5-DILITHIUM-001: expand_mask_vector kahdesti PERAKKAIN, ei
// reset:ia valissa.

`timescale 1ns/1ps

module expand_mask_twice_tb;

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
  logic [511:0] rp1_val, rp2_val;
  logic [15:0] k1_val, k2_val;
  logic [L*256*ZW-1:0] y1_expect, y2_expect;

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/expand_mask_twice_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", rp1_val);
    scan_ok = $fscanf(fh, "%h\n", k1_val);
    scan_ok = $fscanf(fh, "%h\n", y1_expect);
    scan_ok = $fscanf(fh, "%h\n", rp2_val);
    scan_ok = $fscanf(fh, "%h\n", k2_val);
    scan_ok = $fscanf(fh, "%h\n", y2_expect);
    $fclose(fh);

    repeat (3) @(posedge clk);
    reset = 0;

    rho_prime_in = rp1_val; kappa_in = k1_val;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;
    wait (done);
    @(posedge clk);
    if (y_out_flat === y1_expect) $display("OK: ENSIMMAINEN kutsu tasmaa");
    else $display("FAIL: ENSIMMAINEN kutsu EI tasmaa");

    rho_prime_in = rp2_val; kappa_in = k2_val;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;
    wait (done);
    @(posedge clk);
    if (y_out_flat === y2_expect) begin
      $display("OK: TOINEN kutsu (EI reset:ia valissa) tasmaa");
      $display("PASS: expand_mask_vector toimii oikein toistetulla kutsulla");
    end else begin
      $display("FAIL: TOINEN kutsu EI tasmaa");
      $display("  TAMA PALJASTAISI 'toisen kutsun' -bugin expand_mask_vector:ssa");
    end

    $finish;
  end

endmodule
