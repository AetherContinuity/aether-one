// M5-DILITHIUM-001 DK6 S6-testi: hintien muodostus todennus
// dilithium-py:n omaa tulosta vasten.

`timescale 1ns/1ps

module pqc_dilithium_sign_hint_core_tb;

  localparam int CW = 23;
  localparam int K = 6;

  logic clk, reset, start, done, reject;
  logic [K*256*CW-1:0] w_in_flat;
  logic [K*256*CW-1:0] s2_in_flat;
  logic [K*256*CW-1:0] t0_in_flat;
  logic [256*8-1:0] c_in_flat;
  logic [K*256-1:0] h_out_flat;

  always #5 clk = ~clk;

  pqc_dilithium_sign_hint_core #(.CW(CW), .K(K)) dut (
    .clk(clk), .reset(reset), .start(start),
    .w_in_flat(w_in_flat), .s2_in_flat(s2_in_flat), .t0_in_flat(t0_in_flat), .c_in_flat(c_in_flat),
    .done(done), .h_out_flat(h_out_flat), .reject(reject)
  );

  int fh, scan_ok;
  logic [K*256*CW-1:0] w_val, s2_val, t0_val;
  logic [256*8-1:0] c_val;
  logic [K*256-1:0] h_expect;
  int reject_expect;

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/sign_hint_core_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", w_val);
    scan_ok = $fscanf(fh, "%h\n", s2_val);
    scan_ok = $fscanf(fh, "%h\n", t0_val);
    scan_ok = $fscanf(fh, "%h\n", c_val);
    scan_ok = $fscanf(fh, "%h\n", h_expect);
    scan_ok = $fscanf(fh, "%d\n", reject_expect);
    $fclose(fh);

    w_in_flat = w_val; s2_in_flat = s2_val; t0_in_flat = t0_val; c_in_flat = c_val;

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    begin
      int wait_cycles;
      wait_cycles = 0;
      while (!done && wait_cycles < 150000) begin @(posedge clk); wait_cycles++; end
      if (!done) $display("FAIL: aikakatkaisu (%0d syklia)", wait_cycles);
      else $display("Valmis %0d syklin jalkeen, reject=%0b (odotettu %0d)", wait_cycles, reject, reject_expect);
    end

    if (h_out_flat === h_expect && reject == reject_expect[0]) begin
      $display("PASS: hintien muodostus tasmaa taydellisesti");
    end else begin
      int diffs;
      diffs = 0;
      for (int i = 0; i < K*256; i++) begin
        if (h_out_flat[i] !== h_expect[i]) diffs++;
      end
      $display("FAIL: %0d/%0d hintbittia eroaa, reject=%0b (odotettu %0d)", diffs, K*256, reject, reject_expect);
      $fatal(1);
    end

    $display("--------------------------------------------------");
    $finish;
  end

endmodule
