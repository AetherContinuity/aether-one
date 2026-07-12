// pqc_byteencode_d11_tb.sv — d=4
`timescale 1ns/1ps
module pqc_byteencode_d11_tb;
  localparam int D = 11;
  logic [256*D-1:0] f_in, b_out, b_in, f_out;
  pqc_byteencode_dparam #(.D(D)) dut_enc (.f_in(f_in), .b_out(b_out));
  pqc_bytedecode_dparam #(.D(D)) dut_dec (.b_in(b_in), .f_out(f_out));
  int error_count, case_count, fh, scan_ok;
  initial begin
    error_count = 0; case_count = 0;
    fh = $fopen("vectors/byteencode_d11_packed_vectors.txt", "r");
    scan_ok = 1;
    while (!$feof(fh) && scan_ok == 1) begin
      scan_ok = $fscanf(fh, "%h\n", f_in);
      if (scan_ok == 1) begin
        b_in = f_in; // b_packed == f_packed aina (todistettu golden-mallissa)
        #1;
        case_count++;
        if (b_out !== f_in) begin
          $display("FAIL ByteEncode d=%0d: b_out=%h, odotettu %h", D, b_out, f_in);
          error_count++;
        end
        if (f_out !== f_in) begin
          $display("FAIL ByteDecode d=%0d: f_out=%h, odotettu %h", D, f_out, f_in);
          error_count++;
        end
      end
    end
    $fclose(fh);
    if (error_count == 0) $display("OK d=%0d: kaikki %0d testitapausta tasmaavat", D, case_count);
    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS d=%0d", D);
    else begin $display("FAIL d=%0d: %0d virhetta", D, error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end
endmodule
