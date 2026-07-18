// M5-DILITHIUM-001 DK5-testi: UseHint todennus dilithium-py:n omaa
// use_hint()-funktiota vasten.

`timescale 1ns/1ps

module pqc_dilithium_use_hint_tb;

  localparam int CW = 23;

  logic h_in;
  logic [CW-1:0] r_in;
  logic [3:0] result_out;

  pqc_dilithium_use_hint dut (.h_in(h_in), .r_in(r_in), .result_out(result_out));

  int fh, scan_ok, error_count, case_count;
  int h_val, r_val, expect_val;

  initial begin
    error_count = 0; case_count = 0;

    fh = $fopen("dilithium-rtl/use_hint_test_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%d %d %d\n", h_val, r_val, expect_val);
    while (scan_ok == 3) begin
      h_in = h_val[0];
      r_in = r_val[CW-1:0];
      #1;
      if (result_out !== expect_val[3:0]) begin
        $display("FAIL: h=%0d r=%0d -> got=%0d expected=%0d", h_val, r_val, result_out, expect_val);
        error_count++;
      end
      case_count++;
      scan_ok = $fscanf(fh, "%d %d %d\n", h_val, r_val, expect_val);
    end
    $fclose(fh);

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: UseHint tasmaa taydellisesti kaikille %0d testitapaukselle", case_count);
    else begin $display("FAIL: %0d/%0d virhetta", error_count, case_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
