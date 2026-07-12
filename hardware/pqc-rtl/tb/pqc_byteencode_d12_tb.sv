// pqc_byteencode_d12_tb.sv — d=12, sisaltaa reunatapaustestin (segmentit >= Q)
`timescale 1ns/1ps
module pqc_byteencode_d12_tb;
  localparam int D = 12;
  logic [256*D-1:0] f_in, b_out, b_in, f_out;
  pqc_byteencode_dparam #(.D(D)) dut_enc (.f_in(f_in), .b_out(b_out));
  pqc_bytedecode_dparam #(.D(D)) dut_dec (.b_in(b_in), .f_out(f_out));
  int error_count, case_count, fh, scan_ok;
  logic [256*D-1:0] expect_val;

  initial begin
    error_count = 0; case_count = 0;

    // --- Perustapaus: F jo mod Q, round-trip pitaisi sailya ---
    fh = $fopen("vectors/byteencode_d12_packed_vectors.txt", "r");
    scan_ok = 1;
    while (!$feof(fh) && scan_ok == 1) begin
      scan_ok = $fscanf(fh, "%h\n", f_in);
      if (scan_ok == 1) begin
        b_in = f_in;
        #1;
        case_count++;
        if (b_out !== f_in) begin
          $display("FAIL ByteEncode12: b_out=%h, odotettu %h", b_out, f_in);
          error_count++;
        end
        if (f_out !== f_in) begin
          $display("FAIL ByteDecode12 (perustapaus): f_out=%h, odotettu %h", f_out, f_in);
          error_count++;
        end
      end
    end
    $fclose(fh);
    if (error_count == 0) $display("OK d=12 perustapaus: kaikki %0d testitapausta tasmaavat", case_count);

    // --- REUNATAPAUS: segmentit >= Q, pitaisi reduosoitua ByteDecode12:ssa ---
    fh = $fopen("vectors/byteencode_d12_edge_vectors.txt", "r");
    scan_ok = 1;
    while (!$feof(fh) && scan_ok == 1) begin
      scan_ok = $fscanf(fh, "%h\n", b_in);
      if (scan_ok == 1) begin
        scan_ok = $fscanf(fh, "%h\n", expect_val);
      end
      if (scan_ok == 1) begin
        #1;
        case_count++;
        if (f_out !== expect_val) begin
          $display("FAIL ByteDecode12 (reunatapaus, segmentit>=Q): f_out=%h, odotettu %h", f_out, expect_val);
          error_count++;
        end
      end
    end
    $fclose(fh);
    if (error_count == 0) $display("OK d=12 reunatapaus (segmentit>=Q): mod Q -reduktio toimii oikein");

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS d=12 (perustapaus + reunatapaus)");
    else begin $display("FAIL d=12: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end
endmodule
