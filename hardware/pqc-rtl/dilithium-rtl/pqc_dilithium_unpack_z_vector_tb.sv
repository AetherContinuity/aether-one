// M5-DILITHIUM-001 DK5-testi: koko z-vektorin purku (5 polynomia)
// todennus.

`timescale 1ns/1ps

module pqc_dilithium_unpack_z_vector_tb;

  localparam int ZW = 24;
  localparam int L = 5;

  logic [L*256*20-1:0] packed_in;
  logic [L*256*ZW-1:0] z_out_flat;

  pqc_dilithium_unpack_z_vector #(.ZW(ZW), .L(L)) dut (
    .packed_in(packed_in), .z_out_flat(z_out_flat)
  );

  int fh, scan_ok;
  logic [L*256*20-1:0] packed_val;
  logic [L*256*ZW-1:0] expect_out;

  initial begin
    fh = $fopen("dilithium-rtl/unpack_z_vector_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", packed_val);
    scan_ok = $fscanf(fh, "%h\n", expect_out);
    $fclose(fh);

    packed_in = packed_val;
    #1;

    if (z_out_flat === expect_out) begin
      $display("PASS: koko z-vektorin purku (5 polynomia) tasmaa taydellisesti");
    end else begin
      int diffs;
      diffs = 0;
      for (int i = 0; i < L*256; i++) begin
        if (z_out_flat[i*ZW+:ZW] !== expect_out[i*ZW+:ZW]) diffs++;
      end
      $display("FAIL: %0d/%0d kerrointa eroaa", diffs, L*256);
      $fatal(1);
    end

    $display("--------------------------------------------------");
    $finish;
  end

endmodule
