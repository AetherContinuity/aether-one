// M5-DILITHIUM-001 DK5-testi: bit_unpack_z todennus.

`timescale 1ns/1ps

module pqc_dilithium_unpack_z_tb;

  localparam int ZW = 24;

  logic [256*20-1:0] packed_in;
  logic [256*ZW-1:0] z_out_flat;

  pqc_dilithium_unpack_z #(.ZW(ZW)) dut (.packed_in(packed_in), .z_out_flat(z_out_flat));

  int fh, scan_ok;
  logic [256*20-1:0] packed_val;
  logic [256*ZW-1:0] expect_out;

  initial begin
    fh = $fopen("dilithium-rtl/unpack_z_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", packed_val);
    scan_ok = $fscanf(fh, "%h\n", expect_out);
    $fclose(fh);

    packed_in = packed_val;
    #1;

    if (z_out_flat === expect_out) begin
      $display("PASS: bit_unpack_z tasmaa taydellisesti kaikille 256 kertoimelle");
    end else begin
      int diffs;
      diffs = 0;
      for (int i = 0; i < 256; i++) begin
        if (z_out_flat[i*ZW+:ZW] !== expect_out[i*ZW+:ZW]) begin
          diffs++;
          if (diffs <= 5) $display("  ERO kerroin %0d: RTL=%0d golden=%0d", i, $signed(z_out_flat[i*ZW+:ZW]), $signed(expect_out[i*ZW+:ZW]));
        end
      end
      $display("FAIL: %0d/256 kerrointa eroaa", diffs);
      $fatal(1);
    end

    $display("--------------------------------------------------");
    $finish;
  end

endmodule
