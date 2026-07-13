// pqc_keccak_squeeze_tb.sv
// M3 Issue #11 Vaihe C: puristuksen testipenkki, yksi- ja
// monilohko-tapaus erikseen.

`timescale 1ns/1ps

module pqc_keccak_squeeze_tb;

  localparam int RATE_BYTES = 136;
  localparam int MAX_OUT_BYTES = 200;

  logic clk, reset, start, done;
  logic [1599:0] state_in;
  logic [15:0] out_len_bytes;
  logic [8*MAX_OUT_BYTES-1:0] out_data;

  pqc_keccak_squeeze #(.RATE_BYTES(RATE_BYTES), .MAX_OUT_BYTES(MAX_OUT_BYTES)) dut (
    .clk(clk), .reset(reset), .start(start),
    .state_in(state_in), .out_len_bytes(out_len_bytes),
    .out_data(out_data), .done(done)
  );

  always #5 clk = ~clk;

  int fh, scan_ok, error_count, case_count;
  string name;
  int out_len;
  logic [8*MAX_OUT_BYTES-1:0] out_expect;

  initial begin
    error_count = 0; case_count = 0;
    clk = 0; reset = 1; start = 0; state_in = '0; out_len_bytes = 0;

    fh = $fopen("vectors/keccak_squeeze_vectors.txt", "r");

    for (int tc = 0; tc < 2; tc++) begin
      scan_ok = $fscanf(fh, "%s %d\n", name, out_len);
      out_len_bytes = out_len[15:0];
      scan_ok = $fscanf(fh, "%h\n", state_in);
      scan_ok = $fscanf(fh, "%h\n", out_expect);

      repeat (3) @(posedge clk);
      reset = 0;
      @(posedge clk);
      start <= 1'b1;
      @(posedge clk);
      start <= 1'b0;

      while (!done) @(posedge clk);
      #1;

      if (out_data !== out_expect) begin
        $display("FAIL %s: ulostulo poikkeaa golden-mallista", name);
        error_count++;
      end else begin
        $display("OK %s: ulostulo (%0d tavua) tasmaa golden-malliin", name, out_len);
      end

      case_count++;
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
    end
    $fclose(fh);

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: puristus (%0d testitapausta, seka yksi- etta monilohko) tasmaa golden-malliin", case_count);
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
