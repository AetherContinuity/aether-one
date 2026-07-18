// M5-DILITHIUM-001 DK4-testi: bit_pack_s (ETA=4) todennus
// dilithium-py:n omaa tulosta vasten.

`timescale 1ns/1ps

module pqc_dilithium_pack_s_tb;

  logic [256*8-1:0] coeffs_in_flat;
  logic [8*128-1:0] packed_out;

  pqc_dilithium_pack_s #(.ETA(4)) dut (
    .coeffs_in_flat(coeffs_in_flat), .packed_out(packed_out)
  );

  int fh, scan_ok;
  logic [256*8-1:0] coeffs_val;
  logic [8*128-1:0] packed_expect;

  initial begin
    fh = $fopen("dilithium-rtl/pack_s_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", coeffs_val);
    scan_ok = $fscanf(fh, "%h\n", packed_expect);
    $fclose(fh);

    coeffs_in_flat = coeffs_val;
    #1;

    if (packed_out === packed_expect) begin
      $display("PASS: bit_pack_s (ETA=4) tasmaa taydellisesti dilithium-py:n tulokseen");
    end else begin
      $display("FAIL: bit_pack_s EI tasmaa");
      $display("  RTL:    %h", packed_out);
      $display("  golden: %h", packed_expect);
      $fatal(1);
    end

    $display("--------------------------------------------------");
    $finish;
  end

endmodule
