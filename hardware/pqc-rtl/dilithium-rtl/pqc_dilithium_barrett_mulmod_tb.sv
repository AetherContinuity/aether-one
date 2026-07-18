// M5-DILITHIUM-001 DK1-testi: Barrett-kertolaskureduktion todennus
// satunnaisilla arvoilla (verrattu Pythonin suoraan modulolaskuun).

`timescale 1ns/1ps

module pqc_dilithium_barrett_mulmod_tb;

  localparam int CW = 23;
  logic [CW-1:0] a_in, b_in;
  logic [CW-1:0] result_out;

  pqc_dilithium_barrett_mulmod dut (.a_in(a_in), .b_in(b_in), .result_out(result_out));

  int fh, scan_ok, error_count, case_count;
  logic [31:0] a_val, b_val, expect_val;

  initial begin
    error_count = 0; case_count = 0;

    fh = $fopen("dilithium-rtl/barrett_test_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%d %d %d\n", a_val, b_val, expect_val);
    while (scan_ok == 3) begin
      a_in = a_val[CW-1:0];
      b_in = b_val[CW-1:0];
      #1;
      if (result_out !== expect_val[CW-1:0]) begin
        $display("FAIL: a=%0d b=%0d expected=%0d got=%0d", a_val, b_val, expect_val, result_out);
        error_count++;
      end
      case_count++;
      scan_ok = $fscanf(fh, "%d %d %d\n", a_val, b_val, expect_val);
    end
    $fclose(fh);

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: Barrett mulmod tasmaa taydellisesti kaikille %0d testitapaukselle", case_count);
    else begin $display("FAIL: %0d/%0d virhetta", error_count, case_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
