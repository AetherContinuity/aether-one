// M5-DILITHIUM-001 DK5-testi: Decompose todennus dilithium-py:n
// omaa decompose()-funktiota vasten.

`timescale 1ns/1ps

module pqc_dilithium_decompose_tb;

  localparam int CW = 23;

  logic [CW-1:0] r_in;
  logic [3:0] r1_out;
  logic signed [CW-1:0] r0_out;

  pqc_dilithium_decompose dut (.r_in(r_in), .r1_out(r1_out), .r0_out(r0_out));

  int fh, scan_ok, error_count, case_count;
  int r_val, r1_expect, r0_expect;

  initial begin
    error_count = 0; case_count = 0;

    fh = $fopen("dilithium-rtl/decompose_test_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%d %d %d\n", r_val, r1_expect, r0_expect);
    while (scan_ok == 3) begin
      r_in = r_val[CW-1:0];
      #1;
      if (r1_out !== r1_expect[3:0] || r0_out !== r0_expect[CW-1:0]) begin
        $display("FAIL: r=%0d -> got(r1=%0d,r0=%0d) expected(r1=%0d,r0=%0d)",
                  r_val, r1_out, $signed(r0_out), r1_expect, r0_expect);
        error_count++;
      end
      case_count++;
      scan_ok = $fscanf(fh, "%d %d %d\n", r_val, r1_expect, r0_expect);
    end
    $fclose(fh);

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: Decompose tasmaa taydellisesti kaikille %0d testitapaukselle", case_count);
    else begin $display("FAIL: %0d/%0d virhetta", error_count, case_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
