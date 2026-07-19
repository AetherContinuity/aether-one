// M5-DILITHIUM-001: sign_hint_core kahdesti PERAKKAIN SAMASSA
// simulaatiossa (ei reset:ia valissa) - testaa "toisen kutsun"
// -ongelmaa nopeasti.

`timescale 1ns/1ps

module hint_core_twice_tb;

  localparam int CW = 23;
  localparam int K = 6;

  logic clk, reset, start, done, reject;
  logic [K*256*CW-1:0] w_in_flat, s2_in_flat, t0_in_flat;
  logic [256*8-1:0] c_in_flat;
  logic [K*256-1:0] h_out_flat;

  always #5 clk = ~clk;

  pqc_dilithium_sign_hint_core #(.CW(CW), .K(K)) dut (
    .clk(clk), .reset(reset), .start(start),
    .w_in_flat(w_in_flat), .s2_in_flat(s2_in_flat), .t0_in_flat(t0_in_flat), .c_in_flat(c_in_flat),
    .done(done), .h_out_flat(h_out_flat), .reject(reject)
  );

  int fh, scan_ok;
  logic [K*256*CW-1:0] s2_val, t0_val, w1_val, w2_val;
  logic [256*8-1:0] c1_val, c2_val;
  logic [K*256-1:0] h1_expect, h2_expect;
  int rej1_expect, rej2_expect;

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/hint_core_twice_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", s2_val);
    scan_ok = $fscanf(fh, "%h\n", t0_val);
    scan_ok = $fscanf(fh, "%h\n", w1_val);
    scan_ok = $fscanf(fh, "%h\n", c1_val);
    scan_ok = $fscanf(fh, "%h\n", h1_expect);
    scan_ok = $fscanf(fh, "%d\n", rej1_expect);
    scan_ok = $fscanf(fh, "%h\n", w2_val);
    scan_ok = $fscanf(fh, "%h\n", c2_val);
    scan_ok = $fscanf(fh, "%h\n", h2_expect);
    scan_ok = $fscanf(fh, "%d\n", rej2_expect);
    $fclose(fh);

    s2_in_flat = s2_val; t0_in_flat = t0_val;

    repeat (3) @(posedge clk);
    reset = 0;

    // --- ENSIMMAINEN kutsu ---
    w_in_flat = w1_val; c_in_flat = c1_val;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;
    wait (done);
    @(posedge clk);
    if (h_out_flat === h1_expect && reject == rej1_expect[0])
      $display("OK: ENSIMMAINEN kutsu tasmaa (h ja reject)");
    else
      $display("FAIL: ENSIMMAINEN kutsu EI tasmaa");

    // --- TOINEN kutsu, EI reset:ia valissa ---
    w_in_flat = w2_val; c_in_flat = c2_val;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;
    wait (done);
    @(posedge clk);
    if (h_out_flat === h2_expect && reject == rej2_expect[0]) begin
      $display("OK: TOINEN kutsu (EI reset:ia valissa) tasmaa");
      $display("PASS: sign_hint_core toimii oikein toistetulla kutsulla");
    end else begin
      int diffs;
      diffs = 0;
      for (int i = 0; i < K*256; i++) begin
        if (h_out_flat[i] !== h2_expect[i]) diffs++;
      end
      $display("FAIL: TOINEN kutsu EI tasmaa - %0d/%0d hintbittia eroaa, reject=%0b (odotettu %0d)",
                diffs, K*256, reject, rej2_expect);
      $display("  TAMA PALJASTAISI 'toisen kutsun' -bugin sign_hint_core:ssa");
    end

    $finish;
  end

endmodule
