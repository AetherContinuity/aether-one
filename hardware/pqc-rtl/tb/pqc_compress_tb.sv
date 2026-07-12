// pqc_compress_tb.sv
//
// M3 Issue #6 -testipenkki. Lukee sekoitetun COMP/DECOMP-vektoritiedoston,
// ajaa jokaisen rivin, tarkistaa bittitarkasti. Negatiivikontrolli:
// vaihdetaan Compress/Decompress-kaavat tahallaan ristiin.

`timescale 1ns/1ps

module pqc_compress_tb;

  localparam int COEFF_W = 16;
  localparam int Q = 3329;

  logic [3:0] d;
  logic [COEFF_W-1:0] x_in, y_in, compress_out, decompress_out;

  pqc_compress #(.COEFF_W(COEFF_W), .Q(Q)) dut (
    .d(d), .x_in(x_in), .compress_out(compress_out),
    .y_in(y_in), .decompress_out(decompress_out)
  );

  int error_count, comp_count, decomp_count;
  int fh;
  string op;
  int vd, va, vexpect;
  int scan_ok;

  initial begin
    error_count = 0; comp_count = 0; decomp_count = 0;
    x_in = 0; y_in = 0; d = 0;

    fh = $fopen("vectors/compress_vectors.txt", "r");
    scan_ok = 4;
    while (!$feof(fh) && scan_ok == 4) begin
      scan_ok = $fscanf(fh, "%s %d %d %d\n", op, vd, va, vexpect);
      if (scan_ok == 4) begin
        d = vd[3:0];
        if (op == "COMP") begin
          x_in = va[COEFF_W-1:0];
          #1;
          comp_count++;
          if (compress_out !== vexpect[COEFF_W-1:0]) begin
            $display("FAIL COMP d=%0d x=%0d -> %0d, odotettu %0d", vd, va, compress_out, vexpect);
            error_count++;
          end
        end else if (op == "DECOMP") begin
          y_in = va[COEFF_W-1:0];
          #1;
          decomp_count++;
          if (decompress_out !== vexpect[COEFF_W-1:0]) begin
            $display("FAIL DECOMP d=%0d y=%0d -> %0d, odotettu %0d", vd, va, decompress_out, vexpect);
            error_count++;
          end
        end
      end
    end
    $fclose(fh);

    if (error_count == 0) begin
      $display("OK: kaikki %0d Compress + %0d Decompress -testitapausta tasmaavat golden-malliin", comp_count, decomp_count);
    end

    $display("--------------------------------------------------");
    if (error_count == 0) begin
      $display("PASS: Compress/Decompress tasmaa golden-malliin taydellisesti");
    end else begin
      $display("FAIL: %0d virhetta", error_count);
      $fatal(1);
    end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
