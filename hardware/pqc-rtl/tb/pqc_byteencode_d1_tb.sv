// pqc_byteencode_d1_tb.sv
//
// M3 Issue #7, Vaihtoehto A -kokeilu, KORJATTU versio: portit ovat
// pakattuja 256-bittisia vektoreita, ei unpacked-taulukoita (ks.
// pqc_byteencode_d1.sv:n oma kommentti - iverilog ei valita
// unpacked-taulukkoa oikein portin lapi, todistettu eristetylla
// minimitestilla ennen tata korjausta).

`timescale 1ns/1ps

module pqc_byteencode_d1_tb;

  logic [255:0] f_in, b_out;
  logic [255:0] b_in, f_out;

  pqc_byteencode_d1 dut_enc (.f_in(f_in), .b_out(b_out));
  pqc_bytedecode_d1 dut_dec (.b_in(b_in), .f_out(f_out));

  int error_count, case_count;
  int fh;
  int scan_ok;

  initial begin
    error_count = 0; case_count = 0;

    fh = $fopen("vectors/byteencode_d1_packed_vectors.txt", "r");
    scan_ok = 1;
    while (!$feof(fh) && scan_ok == 1) begin
      scan_ok = $fscanf(fh, "%h\n", f_in);
      if (scan_ok == 1) begin
        scan_ok = $fscanf(fh, "%h\n", b_in);
      end
      if (scan_ok == 1) begin
        #1;
        case_count++;

        if (b_out !== b_in) begin
          $display("FAIL ByteEncode1: b_out=%h, odotettu %h", b_out, b_in);
          error_count++;
        end
        if (f_out !== f_in) begin
          $display("FAIL ByteDecode1: f_out=%h, odotettu %h", f_out, f_in);
          error_count++;
        end
      end
    end
    $fclose(fh);

    if (error_count == 0) $display("OK: kaikki %0d testitapausta (ByteEncode1 + ByteDecode1) tasmaavat golden-malliin", case_count);

    // --- NEGATIIVIKONTROLLI: invertoidaan yksi bitti f_in:sta ---
    begin
      logic [255:0] b_before;
      b_before = b_out;
      f_in[0] = ~f_in[0];
      #1;
      if (b_out === b_before) begin
        $display("FAIL: f_in[0]:n inversio ei muuttanut b_out:ta - moduuli ei reagoi!");
        error_count++;
      end else begin
        $display("OK: f_in[0]:n inversio muuttaa b_out:ta - moduuli reagoi todistetusti syotteeseen");
      end
    end

    $display("--------------------------------------------------");
    if (error_count == 0) begin
      $display("PASS: ByteEncode1/ByteDecode1 (Vaihtoehto A, PAKATTU vektoriportti) tasmaa golden-malliin, negatiivikontrolli toimii");
    end else begin
      $display("FAIL: %0d virhetta", error_count);
      $fatal(1);
    end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
