// M5-DILITHIUM-001 DK6 S5-testi: z=y+c*s1 ja normitarkistus
// todennus dilithium-py:n omaa tulosta vasten.

`timescale 1ns/1ps

module pqc_dilithium_sign_z_core_tb;

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
  logic [L*256*ZW-1:0] y_val;
  logic [256*8-1:0] c_val;
  logic [L*256*ZW-1:0] z_expect;
  int reject_expect;

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/sign_z_core_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", s1_val);
    scan_ok = $fscanf(fh, "%h\n", y_val);
    scan_ok = $fscanf(fh, "%h\n", c_val);
    scan_ok = $fscanf(fh, "%h\n", z_expect);
    scan_ok = $fscanf(fh, "%d\n", reject_expect);
    $fclose(fh);

    s1_in_flat = s1_val; y_in_flat = y_val; c_in_flat = c_val;

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    begin
      int wait_cycles;
      wait_cycles = 0;
      while (!done && wait_cycles < 100000) begin @(posedge clk); wait_cycles++; end
      if (!done) $display("FAIL: aikakatkaisu (%0d syklia)", wait_cycles);
      else $display("Valmis %0d syklin jalkeen, reject=%0b (odotettu %0d)", wait_cycles, reject, reject_expect);
    end

    if (z_out_flat === z_expect && reject == reject_expect[0]) begin
      $display("PASS: z=y+c*s1 ja normitarkistus tasmaavat taydellisesti");
    end else begin
      int diffs;
      diffs = 0;
      for (int i = 0; i < L*256; i++) begin
        if (z_out_flat[i*ZW+:ZW] !== z_expect[i*ZW+:ZW]) diffs++;
      end
      $display("FAIL: %0d/%0d kerrointa eroaa, reject=%0b (odotettu %0d)", diffs, L*256, reject, reject_expect);
      $fatal(1);
    end

    $display("--------------------------------------------------");
    $finish;
  end

endmodule
