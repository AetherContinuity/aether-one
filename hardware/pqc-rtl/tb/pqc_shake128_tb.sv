// pqc_shake128_tb.sv
// M3 Issue #14: SHAKE128-testipenkki. Vaihe B (5 testitapausta,
// muuttuva ulostulopituus 16..512 tavua) + Vaihe C (ML-KEM:n oma
// XOF-kayttotyyli, viimeinen testitapaus).

`timescale 1ns/1ps

module pqc_shake128_tb;

  localparam int MAX_BLOCKS = 2;
  localparam int MAX_OUT_BYTES = 512;
  localparam int MAX_MSG_BYTES = 40;
  localparam int MSG_TOTAL_BYTES = 168 * MAX_BLOCKS;

  logic clk, reset, start, done;
  logic [8*MSG_TOTAL_BYTES-1:0] msg_in;
  logic [15:0] msg_len_bytes;
  logic [15:0] out_len_bytes;
  logic [8*MAX_OUT_BYTES-1:0] out_data;

  pqc_shake128 #(.MAX_BLOCKS(MAX_BLOCKS), .MAX_OUT_BYTES(MAX_OUT_BYTES)) dut (
    .clk(clk), .reset(reset), .start(start),
    .msg_in(msg_in), .msg_len_bytes(msg_len_bytes), .out_len_bytes(out_len_bytes),
    .out_data(out_data), .done(done)
  );

  always #5 clk = ~clk;

  int fh, scan_ok, error_count, case_count, olen, mlen;
  string name;
  logic [8*MAX_MSG_BYTES-1:0] msg_raw;
  logic [8*MAX_OUT_BYTES-1:0] out_expect, mask;

  initial begin
    error_count = 0; case_count = 0;
    clk = 0; reset = 1; start = 0; msg_in = '0; msg_len_bytes = 0; out_len_bytes = 0;

    fh = $fopen("vectors/shake128_vectors.txt", "r");

    for (int tc = 0; tc < 6; tc++) begin
      scan_ok = $fscanf(fh, "%s %d %d\n", name, mlen, olen);
      msg_len_bytes = mlen[15:0];
      out_len_bytes = olen[15:0];
      scan_ok = $fscanf(fh, "%h\n", msg_raw);
      msg_in = '0;
      msg_in[8*MAX_MSG_BYTES-1:0] = msg_raw;
      scan_ok = $fscanf(fh, "%h\n", out_expect);

      repeat (3) @(posedge clk);
      reset = 0;
      @(posedge clk);
      start <= 1'b1;
      @(posedge clk);
      start <= 1'b0;

      while (!done) @(posedge clk);
      #1;

      mask = '1;
      if (olen*8 < 8*MAX_OUT_BYTES) mask = mask >> (8*MAX_OUT_BYTES - olen*8);
      if ((out_data & mask) !== (out_expect & mask)) begin
        $display("FAIL %s (out_len=%0d): ulostulo poikkeaa golden-mallista", name, olen);
        error_count++;
      end else begin
        $display("OK %s (out_len=%0d): koko tavujono tasmaa golden-malliin", name, olen);
      end

      case_count++;
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
    end
    $fclose(fh);

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: SHAKE128 (%0d testitapausta, mukaan lukien ML-KEM XOF-tyylinen API-testi) tasmaa golden-malliin", case_count);
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
