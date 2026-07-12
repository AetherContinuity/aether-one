// pqc_multiplyntts_tb.sv
`timescale 1ns/1ps
module pqc_multiplyntts_tb;
  localparam int COEFF_W = 16;
  logic [256*COEFF_W-1:0] f_hat, g_hat, h_hat, h_expect;
  pqc_multiplyntts #(.COEFF_W(COEFF_W)) dut (.f_hat(f_hat), .g_hat(g_hat), .h_hat(h_hat));

  int error_count, case_count, fh, scan_ok;

  initial begin
    error_count = 0; case_count = 0;
    fh = $fopen("vectors/multiplyntts_vectors.txt", "r");
    scan_ok = 1;
    while (!$feof(fh) && scan_ok == 1) begin
      scan_ok = $fscanf(fh, "%h\n", f_hat);
      if (scan_ok == 1) scan_ok = $fscanf(fh, "%h\n", g_hat);
      if (scan_ok == 1) scan_ok = $fscanf(fh, "%h\n", h_expect);
      if (scan_ok == 1) begin
        #1;
        case_count++;
        if (h_hat !== h_expect) begin
          $display("FAIL tapaus %0d: h_hat=%h, odotettu %h", case_count, h_hat, h_expect);
          error_count++;
        end
      end
    end
    $fclose(fh);
    if (error_count == 0) $display("OK: kaikki %0d testitapausta tasmaavat golden-malliin", case_count);

    // Negatiivikontrolli: vaihdetaan f_hat ja g_hat keskenaan - MultiplyNTTs
    // on kommutatiivinen periaatteessa (Tq on kommutatiivinen rengas), joten
    // TAMA EI riita negatiivikontrolliksi - vaihdetaan sen sijaan yksi
    // f_hat-alkio ja varmistetaan etta h_hat muuttuu.
    begin
      logic [256*COEFF_W-1:0] h_before;
      h_before = h_hat;
      f_hat[15:0] = f_hat[15:0] + 16'd1;
      #1;
      if (h_hat === h_before) begin
        $display("FAIL: f_hat:n muutos ei vaikuttanut h_hat:aan!");
        error_count++;
      end else begin
        $display("OK: f_hat:n muutos vaikuttaa h_hat:aan - moduuli reagoi todistetusti syotteeseen");
      end
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: MultiplyNTTs tasmaa golden-malliin, negatiivikontrolli toimii");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end
endmodule
