// pqc_samplepolycbd_tb.sv
// M3 Issue #15: SamplePolyCBD-testipenkki, molemmat eta-arvot.

`timescale 1ns/1ps

module pqc_samplepolycbd_tb;

  // --- eta=2 ---
  logic [8*64*2-1:0] B_in_2;
  logic [16*256-1:0] f_out_2, f_expect_2;
  pqc_samplepolycbd #(.ETA(2)) dut2 (.B_in(B_in_2), .f_out(f_out_2));

  // --- eta=3 ---
  logic [8*64*3-1:0] B_in_3;
  logic [16*256-1:0] f_out_3, f_expect_3;
  pqc_samplepolycbd #(.ETA(3)) dut3 (.B_in(B_in_3), .f_out(f_out_3));

  int fh, scan_ok, error_count, case_count;
  string name;

  initial begin
    error_count = 0; case_count = 0;
    B_in_2 = '0; B_in_3 = '0;

    // --- eta=2 ---
    fh = $fopen("vectors/samplepolycbd_eta2_vectors.txt", "r");
    for (int tc = 0; tc < 3; tc++) begin
      scan_ok = $fscanf(fh, "%s\n", name);
      scan_ok = $fscanf(fh, "%h\n", B_in_2);
      scan_ok = $fscanf(fh, "%h\n", f_expect_2);
      #1;
      if (f_out_2 !== f_expect_2) begin
        $display("FAIL eta=2 %s: f_out poikkeaa golden-mallista", name);
        error_count++;
      end else $display("OK eta=2 %s: f_out tasmaa golden-malliin", name);
      case_count++;
    end
    $fclose(fh);

    // --- eta=3 ---
    fh = $fopen("vectors/samplepolycbd_eta3_vectors.txt", "r");
    for (int tc = 0; tc < 2; tc++) begin
      scan_ok = $fscanf(fh, "%s\n", name);
      scan_ok = $fscanf(fh, "%h\n", B_in_3);
      scan_ok = $fscanf(fh, "%h\n", f_expect_3);
      #1;
      if (f_out_3 !== f_expect_3) begin
        $display("FAIL eta=3 %s: f_out poikkeaa golden-mallista", name);
        error_count++;
      end else $display("OK eta=3 %s: f_out tasmaa golden-malliin", name);
      case_count++;
    end
    $fclose(fh);

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: SamplePolyCBD (%0d testitapausta, eta=2 ja eta=3) tasmaa golden-malliin", case_count);
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
