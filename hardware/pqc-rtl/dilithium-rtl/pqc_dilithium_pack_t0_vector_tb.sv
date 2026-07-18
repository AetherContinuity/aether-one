// M5-DILITHIUM-001 DK4-testi: koko t0-vektorin pakkaus (6
// polynomia) todennus.

`timescale 1ns/1ps

module pqc_dilithium_pack_t0_vector_tb;

  localparam int CW = 23;
  localparam int K = 6;

  logic [K*256*CW-1:0] t0_in_flat;
  logic [K*256*13-1:0] t0_packed_out;

  pqc_dilithium_pack_t0_vector #(.CW(CW), .K(K)) dut (
    .t0_in_flat(t0_in_flat), .t0_packed_out(t0_packed_out)
  );

  int fh, scan_ok;
  logic [K*256*CW-1:0] t0_val;
  logic [K*256*13-1:0] t0_packed_expect;

  initial begin
    fh = $fopen("dilithium-rtl/pack_t0_vector_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", t0_val);
    scan_ok = $fscanf(fh, "%h\n", t0_packed_expect);
    $fclose(fh);

    t0_in_flat = t0_val;
    #1;

    if (t0_packed_out === t0_packed_expect) begin
      $display("PASS: koko t0-pakkaus (6 polynomia) tasmaa taydellisesti");
    end else begin
      $display("FAIL: t0-pakkaus EI tasmaa");
      $fatal(1);
    end

    $display("--------------------------------------------------");
    $finish;
  end

endmodule
