// M5-DILITHIUM-001 DK4-testi: koko s1/s2-vektorin pakkaus (11
// polynomia) todennus.

`timescale 1ns/1ps

module pqc_dilithium_pack_s_vector_tb;

  localparam int K = 6;
  localparam int L = 5;

  logic [L*256*8-1:0] s1_in_flat;
  logic [K*256*8-1:0] s2_in_flat;
  logic [L*8*128-1:0] s1_packed_out;
  logic [K*8*128-1:0] s2_packed_out;

  pqc_dilithium_pack_s_vector #(.K(K), .L(L)) dut (
    .s1_in_flat(s1_in_flat), .s2_in_flat(s2_in_flat),
    .s1_packed_out(s1_packed_out), .s2_packed_out(s2_packed_out)
  );

  int fh, scan_ok, error_count;
  logic [L*256*8-1:0] s1_val;
  logic [K*256*8-1:0] s2_val;
  logic [L*8*128-1:0] s1_packed_expect;
  logic [K*8*128-1:0] s2_packed_expect;

  initial begin
    error_count = 0;

    fh = $fopen("dilithium-rtl/pack_s_vector_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", s1_val);
    scan_ok = $fscanf(fh, "%h\n", s2_val);
    scan_ok = $fscanf(fh, "%h\n", s1_packed_expect);
    scan_ok = $fscanf(fh, "%h\n", s2_packed_expect);
    $fclose(fh);

    s1_in_flat = s1_val; s2_in_flat = s2_val;
    #1;

    if (s1_packed_out === s1_packed_expect) $display("OK: s1-pakkaus (5 polynomia) tasmaa taydellisesti");
    else begin $display("FAIL: s1-pakkaus EI tasmaa"); error_count++; end

    if (s2_packed_out === s2_packed_expect) $display("OK: s2-pakkaus (6 polynomia) tasmaa taydellisesti");
    else begin $display("FAIL: s2-pakkaus EI tasmaa"); error_count++; end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: koko s1+s2-pakkaus (11 polynomia) tasmaa taydellisesti");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
