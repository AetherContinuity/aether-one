// M5-DILITHIUM-001 DK4-testi: bit_pack_t0 todennus dilithium-py:n
// omaa tulosta vasten.

`timescale 1ns/1ps

module pqc_dilithium_pack_t0_tb;

  localparam int CW = 23;

  logic [256*CW-1:0] t0_in_flat;
  logic [256*13-1:0] packed_out;

  pqc_dilithium_pack_t0 #(.CW(CW)) dut (
    .t0_in_flat(t0_in_flat), .packed_out(packed_out)
  );

  int fh, scan_ok;
  logic [256*CW-1:0] t0_val;
  logic [256*13-1:0] packed_expect;

  initial begin
    fh = $fopen("dilithium-rtl/pack_t0_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", t0_val);
    scan_ok = $fscanf(fh, "%h\n", packed_expect);
    $fclose(fh);

    t0_in_flat = t0_val;
    #1;

    if (packed_out === packed_expect) begin
      $display("PASS: bit_pack_t0 tasmaa taydellisesti dilithium-py:n tulokseen");
    end else begin
      $display("FAIL: bit_pack_t0 EI tasmaa");
      $display("  RTL:    %h", packed_out);
      $display("  golden: %h", packed_expect);
      $fatal(1);
    end

    $display("--------------------------------------------------");
    $finish;
  end

endmodule
