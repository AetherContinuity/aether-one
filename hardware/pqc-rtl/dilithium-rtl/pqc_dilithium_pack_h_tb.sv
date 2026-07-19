// M5-DILITHIUM-001 DK6 S8-testi: pack_h todennus dilithium-py:n
// omaa _pack_h()-tulosta vasten.

`timescale 1ns/1ps

module pqc_dilithium_pack_h_tb;

  localparam int OMEGA = 55;
  localparam int K = 6;

  logic clk, reset, start, done;
  logic [K*256-1:0] h_in_flat;
  logic [8*(OMEGA+K)-1:0] h_bytes_out;

  always #5 clk = ~clk;

  pqc_dilithium_pack_h #(.OMEGA(OMEGA), .K(K)) dut (
    .clk(clk), .reset(reset), .start(start),
    .h_in_flat(h_in_flat), .done(done), .h_bytes_out(h_bytes_out)
  );

  int fh, scan_ok;
  logic [K*256-1:0] h_val;
  logic [8*(OMEGA+K)-1:0] expect_out;

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/pack_h_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", h_val);
    scan_ok = $fscanf(fh, "%h\n", expect_out);
    $fclose(fh);

    h_in_flat = h_val;

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    begin
      int wait_cycles;
      wait_cycles = 0;
      while (!done && wait_cycles < 2000) begin @(posedge clk); wait_cycles++; end
      if (!done) $display("FAIL: aikakatkaisu (%0d syklia)", wait_cycles);
      else $display("Valmis %0d syklin jalkeen", wait_cycles);
    end

    if (h_bytes_out === expect_out) begin
      $display("PASS: pack_h tasmaa taydellisesti dilithium-py:n tulokseen");
    end else begin
      int diffs;
      diffs = 0;
      for (int b = 0; b < OMEGA+K; b++) begin
        if (h_bytes_out[b*8+:8] !== expect_out[b*8+:8]) begin
          diffs++;
          if (diffs <= 10) $display("  ERO tavu %0d: RTL=%0d golden=%0d", b, h_bytes_out[b*8+:8], expect_out[b*8+:8]);
        end
      end
      $display("FAIL: %0d/%0d tavua eroaa", diffs, OMEGA+K);
      $fatal(1);
    end

    $display("--------------------------------------------------");
    $finish;
  end

endmodule
