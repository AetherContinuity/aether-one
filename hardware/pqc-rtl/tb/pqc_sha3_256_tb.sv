// pqc_sha3_256_tb.sv
// M3 Issue #12: SHA3-256-huippumoduulin testipenkki. Nelja
// testitapausta, mukaan lukien kayttajan oma ehdotus (32-tavuinen
// API-tason regressiotesti ML-KEM:n tulevaa H(s)-kayttoa varten).

`timescale 1ns/1ps

module pqc_sha3_256_tb;

  localparam int MAX_BLOCKS = 2;
  localparam int TOTAL_BYTES = 136 * MAX_BLOCKS;

  logic clk, reset, start, done;
  logic [8*TOTAL_BYTES-1:0] msg_in;
  logic [15:0] msg_len_bytes;
  logic [255:0] digest_out;

  pqc_sha3_256 #(.MAX_BLOCKS(MAX_BLOCKS)) dut (
    .clk(clk), .reset(reset), .start(start),
    .msg_in(msg_in), .msg_len_bytes(msg_len_bytes),
    .digest_out(digest_out), .done(done)
  );

  always #5 clk = ~clk;

  int fh, scan_ok, error_count, case_count, mlen;
  string name;
  logic [255:0] digest_expect;

  initial begin
    error_count = 0; case_count = 0;
    clk = 0; reset = 1; start = 0; msg_in = '0; msg_len_bytes = 0;

    fh = $fopen("vectors/sha3_256_vectors.txt", "r");

    for (int tc = 0; tc < 4; tc++) begin
      scan_ok = $fscanf(fh, "%s %d\n", name, mlen);
      msg_len_bytes = mlen[15:0];
      scan_ok = $fscanf(fh, "%h\n", msg_in);
      scan_ok = $fscanf(fh, "%h\n", digest_expect);

      repeat (3) @(posedge clk);
      reset = 0;
      @(posedge clk);
      start <= 1'b1;
      @(posedge clk);
      start <= 1'b0;

      while (!done) @(posedge clk);
      #1;

      if (digest_out !== digest_expect) begin
        $display("FAIL %s: digest=%h, odotettu %h", name, digest_out, digest_expect);
        error_count++;
      end else begin
        $display("OK %s: SHA3-256(%0d tavua) tasmaa golden-malliin", name, mlen);
      end

      case_count++;
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
    end
    $fclose(fh);

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: SHA3-256 (%0d testitapausta, mukaan lukien ML-KEM-tyylinen API-testi) tasmaa golden-malliin", case_count);
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
