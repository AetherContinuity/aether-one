// M5-DILITHIUM-001 DK6 S8-testi: koko z-vektorin pakkaus (5
// polynomia) todennus.

`timescale 1ns/1ps

module pqc_dilithium_pack_z_vector_tb;

  localparam int ZW = 24;
  localparam int L = 5;

  logic [L*256*ZW-1:0] z_in_flat;
  logic [L*256*20-1:0] packed_out;

  pqc_dilithium_pack_z_vector #(.ZW(ZW), .L(L)) dut (
    .z_in_flat(z_in_flat), .packed_out(packed_out)
  );

  int fh, scan_ok;
  logic [L*256*ZW-1:0] z_val;
  logic [L*256*20-1:0] expect_out;

  initial begin
    fh = $fopen("dilithium-rtl/pack_z_vector_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", z_val);
    scan_ok = $fscanf(fh, "%h\n", expect_out);
    $fclose(fh);

    z_in_flat = z_val;
    #1;

    if (packed_out === expect_out) begin
      $display("PASS: koko z-vektorin pakkaus (5 polynomia) tasmaa taydellisesti");
    end else begin
      $display("FAIL: z-vektorin pakkaus EI tasmaa");
      $fatal(1);
    end

    $display("--------------------------------------------------");
    $finish;
  end

endmodule
