// M5-DILITHIUM-001 DK6-testi: MakeHint todennus dilithium-py:n
// omaa make_hint()-funktiota vasten.

`timescale 1ns/1ps

module pqc_dilithium_make_hint_tb;

  localparam int CW = 23;

  logic [CW-1:0] z_in, r_in;
  logic h_out;

  pqc_dilithium_make_hint dut (.z_in(z_in), .r_in(r_in), .h_out(h_out));

  int fh, scan_ok, error_count, case_count;
  int z_val, r_val, h_expect;

  initial begin
    error_count = 0; case_count = 0;

    fh = $fopen("dilithium-rtl/make_hint_test_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%d %d %d\n", z_val, r_val, h_expect);
    while (scan_ok == 3) begin
      z_in = z_val[CW-1:0];
      r_in = r_val[CW-1:0];
      #1;
      if (h_out !== h_expect[0]) begin
        $display("FAIL: z=%0d r=%0d -> got=%0b expected=%0d", z_val, r_val, h_out, h_expect);
        error_count++;
      end
      case_count++;
      scan_ok = $fscanf(fh, "%d %d %d\n", z_val, r_val, h_expect);
    end
    $fclose(fh);

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: MakeHint tasmaa taydellisesti kaikille %0d testitapaukselle", case_count);
    else begin $display("FAIL: %0d/%0d virhetta", error_count, case_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
