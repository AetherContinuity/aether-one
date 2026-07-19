// M5-DILITHIUM-001 DK6 S8-testi: bit_pack_z todennus dilithium-py:n
// omaa tulosta vasten.

`timescale 1ns/1ps

module pqc_dilithium_pack_z_tb;

  localparam int ZW = 24;

  logic [256*ZW-1:0] z_in_flat;
  logic [256*20-1:0] packed_out;

  pqc_dilithium_pack_z #(.ZW(ZW)) dut (.z_in_flat(z_in_flat), .packed_out(packed_out));

  int fh, scan_ok;
  logic [256*ZW-1:0] z_val;
  logic [256*20-1:0] expect_out;

  initial begin
    fh = $fopen("dilithium-rtl/pack_z_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", z_val);
    scan_ok = $fscanf(fh, "%h\n", expect_out);
    $fclose(fh);

    z_in_flat = z_val;
    #1;

    if (packed_out === expect_out) begin
      $display("PASS: bit_pack_z tasmaa taydellisesti dilithium-py:n tulokseen");
    end else begin
      $display("FAIL: bit_pack_z EI tasmaa");
      $fatal(1);
    end

    $display("--------------------------------------------------");
    $finish;
  end

endmodule
