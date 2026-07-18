// M5-DILITHIUM-001 DK4-testi: Power2Round koko t-vektorille (6
// polynomia) todennus dilithium-py:n omaa t.power_2_round(D)-tulosta
// vasten.

`timescale 1ns/1ps

module pqc_dilithium_power2round_vector_tb;

  localparam int CW = 23;
  localparam int D = 13;
  localparam int K = 6;

  logic [K*256*CW-1:0] t_in_flat;
  logic [K*256*(CW-D)-1:0] t1_out_flat;
  logic [K*256*CW-1:0] t0_out_flat;

  pqc_dilithium_power2round_vector #(.CW(CW), .D(D), .K(K)) dut (
    .t_in_flat(t_in_flat), .t1_out_flat(t1_out_flat), .t0_out_flat(t0_out_flat)
  );

  int fh, scan_ok, error_count;
  logic [K*256*CW-1:0] t_val;
  logic [K*256*(CW-D)-1:0] t1_expect;
  logic [K*256*CW-1:0] t0_expect;

  initial begin
    error_count = 0;

    fh = $fopen("dilithium-rtl/power2round_vector_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", t_val);
    scan_ok = $fscanf(fh, "%h\n", t1_expect);
    scan_ok = $fscanf(fh, "%h\n", t0_expect);
    $fclose(fh);

    t_in_flat = t_val;
    #1;

    if (t1_out_flat === t1_expect) $display("OK: t1 (6*256 kerrointa) tasmaa taydellisesti");
    else begin $display("FAIL: t1 EI tasmaa"); error_count++; end

    if (t0_out_flat === t0_expect) $display("OK: t0 (6*256 kerrointa) tasmaa taydellisesti");
    else begin $display("FAIL: t0 EI tasmaa"); error_count++; end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: Power2Round koko t-vektorille tasmaa taydellisesti");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
