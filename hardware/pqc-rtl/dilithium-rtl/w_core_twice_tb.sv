// M5-DILITHIUM-001: sign_w_core kahdesti PERAKKAIN, ei reset:ia
// valissa.

`timescale 1ns/1ps

module w_core_twice_tb;

  localparam int CW = 23;
  localparam int K = 6;
  localparam int L = 5;

  logic clk, reset, start, done;
  logic [K*L*256*CW-1:0] A_hat_in;
  logic [L*256*CW-1:0] y_in_flat;
  logic [K*256*CW-1:0] w_out_flat;

  always #5 clk = ~clk;

  pqc_dilithium_sign_w_core #(.CW(CW), .K(K), .L(L)) dut (
    .clk(clk), .reset(reset), .start(start),
    .A_hat_in(A_hat_in), .y_in_flat(y_in_flat),
    .done(done), .w_out_flat(w_out_flat)
  );

  int fh, scan_ok;
  logic [K*L*256*CW-1:0] A_val;
  logic [L*256*CW-1:0] y1_val, y2_val;
  logic [K*256*CW-1:0] w1_expect, w2_expect;

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/w_core_twice_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", A_val);
    scan_ok = $fscanf(fh, "%h\n", y1_val);
    scan_ok = $fscanf(fh, "%h\n", w1_expect);
    scan_ok = $fscanf(fh, "%h\n", y2_val);
    scan_ok = $fscanf(fh, "%h\n", w2_expect);
    $fclose(fh);

    A_hat_in = A_val;

    repeat (3) @(posedge clk);
    reset = 0;

    y_in_flat = y1_val;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;
    wait (done);
    @(posedge clk);
    if (w_out_flat === w1_expect) $display("OK: ENSIMMAINEN kutsu tasmaa");
    else $display("FAIL: ENSIMMAINEN kutsu EI tasmaa");

    y_in_flat = y2_val;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;
    wait (done);
    @(posedge clk);
    if (w_out_flat === w2_expect) begin
      $display("OK: TOINEN kutsu (EI reset:ia valissa) tasmaa");
      $display("PASS: sign_w_core toimii oikein toistetulla kutsulla");
    end else begin
      int diffs;
      diffs = 0;
      for (int p = 0; p < K; p++) begin
        if (w_out_flat[p*256*CW +: 256*CW] !== w2_expect[p*256*CW +: 256*CW]) diffs++;
      end
      $display("FAIL: TOINEN kutsu EI tasmaa - %0d/%0d polynomia eroaa", diffs, K);
      $display("  TAMA PALJASTAISI 'toisen kutsun' -bugin sign_w_core:ssa");
    end

    $finish;
  end

endmodule
