// pqc_keccak_pad_tb.sv
// M3 Issue #11 Vaihe A: pehmennyksen (pad10*1) testipenkki, kolme
// kriittista reunatapausta, TAYSIN IRRALLAAN permutaatiosta.

`timescale 1ns/1ps

module pqc_keccak_pad_tb;

  localparam int RATE_BYTES = 136;
  localparam int MAX_BLOCKS = 2;
  localparam int TOTAL_BYTES = RATE_BYTES * MAX_BLOCKS;

  logic [8*TOTAL_BYTES-1:0] msg_in, padded_out, padded_expect;
  logic [15:0] msg_len_bytes;
  logic [7:0] num_blocks;
  int num_blocks_expect;

  pqc_keccak_pad #(.RATE_BYTES(RATE_BYTES), .MAX_BLOCKS(MAX_BLOCKS), .DOMAIN_SUFFIX(8'h06)) dut (
    .msg_in(msg_in), .msg_len_bytes(msg_len_bytes),
    .padded_out(padded_out), .num_blocks(num_blocks)
  );

  int error_count, fh, scan_ok;
  string name;

  initial begin
    error_count = 0;
    fh = $fopen("vectors/keccak_pad_vectors.txt", "r");

    for (int tc = 0; tc < 3; tc++) begin
      scan_ok = $fscanf(fh, "%s %d %d\n", name, msg_len_bytes, num_blocks_expect);
      scan_ok = $fscanf(fh, "%h\n", msg_in);
      scan_ok = $fscanf(fh, "%h\n", padded_expect);

      #1;

      if (num_blocks !== num_blocks_expect[7:0]) begin
        $display("FAIL %s: num_blocks=%0d, odotettu %0d", name, num_blocks, num_blocks_expect);
        error_count++;
      end
      if (padded_out !== padded_expect) begin
        $display("FAIL %s: padded_out poikkeaa golden-mallista", name);
        error_count++;
      end
      if (num_blocks === num_blocks_expect[7:0] && padded_out === padded_expect) begin
        $display("OK %s: num_blocks=%0d, padded_out tasmaa", name, num_blocks);
      end
    end
    $fclose(fh);

    // Negatiivikontrolli: muutetaan msg_len_bytes yhdella, varmistetaan etta tulos muuttuu
    begin
      logic [8*TOTAL_BYTES-1:0] padded_prior;
      padded_prior = padded_out;
      msg_len_bytes = msg_len_bytes + 1;
      #1;
      if (padded_out === padded_prior) begin
        $display("FAIL: msg_len_bytes:n muutos ei vaikuttanut padded_out:iin!");
        error_count++;
      end else $display("OK: msg_len_bytes:n muutos vaikuttaa padded_out:iin - moduuli reagoi todistetusti");
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: pad10*1 kaikki kolme reunatapausta tasmaavat golden-malliin");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
