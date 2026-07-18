// M5-DILITHIUM-001 DK5-testi: unpack_h todennus dilithium-py:n omaa
// _unpack_h()-tulosta vasten.

`timescale 1ns/1ps

module pqc_dilithium_unpack_h_tb;

  localparam int OMEGA = 55;
  localparam int K = 6;

  logic clk, reset, start, done;
  logic [8*(OMEGA+K)-1:0] h_bytes_in;
  logic [K*256-1:0] h_out_flat;

  always #5 clk = ~clk;

  pqc_dilithium_unpack_h #(.OMEGA(OMEGA), .K(K)) dut (
    .clk(clk), .reset(reset), .start(start),
    .h_bytes_in(h_bytes_in), .done(done), .h_out_flat(h_out_flat)
  );

  int fh, scan_ok;
  logic [8*(OMEGA+K)-1:0] h_bytes_val;
  logic [K*256-1:0] expect_out;

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/unpack_h_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", h_bytes_val);
    scan_ok = $fscanf(fh, "%h\n", expect_out);
    $fclose(fh);

    h_bytes_in = h_bytes_val;

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

    if (h_out_flat === expect_out) begin
      $display("PASS: unpack_h tasmaa taydellisesti kaikille K polynomille");
    end else begin
      int diffs;
      diffs = 0;
      for (int i = 0; i < K*256; i++) begin
        if (h_out_flat[i] !== expect_out[i]) diffs++;
      end
      $display("FAIL: %0d/%0d bittia eroaa", diffs, K*256);
      $fatal(1);
    end

    $display("--------------------------------------------------");
    $finish;
  end

endmodule
