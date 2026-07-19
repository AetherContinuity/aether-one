// M5-DILITHIUM-001: sign_z_core kahdesti PERAKKAIN SAMASSA
// simulaatiossa (ei reset:ia valissa, vain start-pulssi uudestaan) -
// testaa nimenomaan "toisen kutsun" -ongelmaa nopeasti (~2x49000
// sykli 2x242000+ sijaan).

`timescale 1ns/1ps

module z_core_twice_tb;

  localparam int CW = 23;
  localparam int L = 5;
  localparam int ZW = 24;

  logic clk, reset, start, done, reject;
  logic [L*256*CW-1:0] s1_in_flat;
  logic [L*256*ZW-1:0] y_in_flat;
  logic [256*8-1:0] c_in_flat;
  logic [L*256*ZW-1:0] z_out_flat;

  always #5 clk = ~clk;

  pqc_dilithium_sign_z_core #(.CW(CW), .L(L), .ZW(ZW)) dut (
    .clk(clk), .reset(reset), .start(start),
    .s1_in_flat(s1_in_flat), .y_in_flat(y_in_flat), .c_in_flat(c_in_flat),
    .done(done), .z_out_flat(z_out_flat), .reject(reject)
  );

  int fh, scan_ok;
  logic [L*256*CW-1:0] s1_val;
  logic [L*256*ZW-1:0] y1_val, y2_val, z1_expect, z2_expect;
  logic [256*8-1:0] c1_val, c2_val;

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/z_core_twice_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", s1_val);
    scan_ok = $fscanf(fh, "%h\n", y1_val);
    scan_ok = $fscanf(fh, "%h\n", c1_val);
    scan_ok = $fscanf(fh, "%h\n", z1_expect);
    scan_ok = $fscanf(fh, "%h\n", y2_val);
    scan_ok = $fscanf(fh, "%h\n", c2_val);
    scan_ok = $fscanf(fh, "%h\n", z2_expect);
    $fclose(fh);

    s1_in_flat = s1_val;

    repeat (3) @(posedge clk);
    reset = 0;

    // --- ENSIMMAINEN kutsu ---
    y_in_flat = y1_val; c_in_flat = c1_val;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;
    wait (done);
    @(posedge clk);
    if (z_out_flat === z1_expect) $display("OK: ENSIMMAINEN kutsu tasmaa");
    else $display("FAIL: ENSIMMAINEN kutsu EI tasmaa");

    // --- TOINEN kutsu, EI reset:ia valissa (vain start uudestaan) ---
    y_in_flat = y2_val; c_in_flat = c2_val;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;
    wait (done);
    @(posedge clk);
    if (z_out_flat === z2_expect) begin
      $display("OK: TOINEN kutsu (EI reset:ia valissa) tasmaa");
      $display("PASS: sign_z_core toimii oikein toistetulla kutsulla");
    end else begin
      int diffs;
      diffs = 0;
      for (int i = 0; i < L*256; i++) begin
        if (z_out_flat[i*ZW+:ZW] !== z2_expect[i*ZW+:ZW]) diffs++;
      end
      $display("FAIL: TOINEN kutsu EI tasmaa - %0d/%0d kerrointa eroaa", diffs, L*256);
      $display("  Tama PALJASTAISI 'toisen kutsun' -bugin sign_z_core:ssa");
    end

    $finish;
  end

endmodule
