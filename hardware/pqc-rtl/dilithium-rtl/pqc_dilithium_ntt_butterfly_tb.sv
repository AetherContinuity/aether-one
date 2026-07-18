// M5-DILITHIUM-001 DK1-testi: yksittaisen NTT-butterflyn todennus
// dilithium-py:n omaa to_ntt()-kaavaa vasten, kirjaston OMILLA
// zeta-arvoilla (ei omaa uudelleentoteutusta bittikaannosta varten).

`timescale 1ns/1ps

module pqc_dilithium_ntt_butterfly_tb;

  localparam int CW = 23;
  logic [CW-1:0] a_in, b_in, zeta_in;
  logic [CW-1:0] a_out, b_out;

  pqc_dilithium_ntt_butterfly dut (
    .a_in(a_in), .b_in(b_in), .zeta_in(zeta_in),
    .a_out(a_out), .b_out(b_out)
  );

  int fh, scan_ok, error_count, case_count;
  logic [31:0] a_val, b_val, z_val, exp_a, exp_b;

  initial begin
    error_count = 0; case_count = 0;

    fh = $fopen("dilithium-rtl/butterfly_test_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%d %d %d %d %d\n", a_val, b_val, z_val, exp_a, exp_b);
    while (scan_ok == 5) begin
      a_in = a_val[CW-1:0];
      b_in = b_val[CW-1:0];
      zeta_in = z_val[CW-1:0];
      #1;
      if (a_out !== exp_a[CW-1:0] || b_out !== exp_b[CW-1:0]) begin
        $display("FAIL: a=%0d b=%0d zeta=%0d -> got(a=%0d,b=%0d) expected(a=%0d,b=%0d)",
                  a_val, b_val, z_val, a_out, b_out, exp_a, exp_b);
        error_count++;
      end
      case_count++;
      scan_ok = $fscanf(fh, "%d %d %d %d %d\n", a_val, b_val, z_val, exp_a, exp_b);
    end
    $fclose(fh);

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: NTT-butterfly tasmaa taydellisesti kaikille %0d testitapaukselle", case_count);
    else begin $display("FAIL: %0d/%0d virhetta", error_count, case_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
