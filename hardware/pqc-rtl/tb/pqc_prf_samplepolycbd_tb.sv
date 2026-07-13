// pqc_prf_samplepolycbd_tb.sv
// M3 Issue #15, Kerros 1: PRF+SamplePolyCBD-testipenkki, molemmat eta-
// arvot, useilla N-arvoilla (varmistaa N-laskurin oikean vaikutuksen).

`timescale 1ns/1ps

module pqc_prf_samplepolycbd_tb;

  logic clk, reset, start2, start3;
  logic [255:0] seed_s;
  logic [7:0] counter_n;
  logic [16*256-1:0] f_out_2, f_out_3;
  logic done2, done3;

  pqc_prf_samplepolycbd #(.ETA(2)) dut2 (
    .clk(clk), .reset(reset), .start(start2),
    .seed_s(seed_s), .counter_n(counter_n), .f_out(f_out_2), .done(done2)
  );
  pqc_prf_samplepolycbd #(.ETA(3)) dut3 (
    .clk(clk), .reset(reset), .start(start3),
    .seed_s(seed_s), .counter_n(counter_n), .f_out(f_out_3), .done(done3)
  );

  always #5 clk = ~clk;

  int fh, scan_ok, error_count, case_count, eta_v, n_v;
  string name;
  logic [16*256-1:0] f_expect;

  initial begin
    error_count = 0; case_count = 0;
    clk = 0; reset = 1; start2 = 0; start3 = 0; seed_s = '0; counter_n = 0;

    fh = $fopen("vectors/prf_samplepolycbd_vectors.txt", "r");

    for (int tc = 0; tc < 6; tc++) begin
      scan_ok = $fscanf(fh, "%s %d %d\n", name, eta_v, n_v);
      counter_n = n_v[7:0];
      scan_ok = $fscanf(fh, "%h\n", seed_s);
      scan_ok = $fscanf(fh, "%h\n", f_expect);

      repeat (3) @(posedge clk);
      reset = 0;
      @(posedge clk);

      if (eta_v == 2) begin
        start2 <= 1'b1;
        @(posedge clk);
        start2 <= 1'b0;
        while (!done2) @(posedge clk);
        #1;
        if (f_out_2 !== f_expect) begin
          $display("FAIL %s: f_out poikkeaa golden-mallista", name);
          error_count++;
        end else $display("OK %s: f_out tasmaa golden-malliin", name);
      end else begin
        start3 <= 1'b1;
        @(posedge clk);
        start3 <= 1'b0;
        while (!done3) @(posedge clk);
        #1;
        if (f_out_3 !== f_expect) begin
          $display("FAIL %s: f_out poikkeaa golden-mallista", name);
          error_count++;
        end else $display("OK %s: f_out tasmaa golden-malliin", name);
      end

      case_count++;
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
    end
    $fclose(fh);

    // Negatiivikontrolli: sama sigma, kaksi eri N:aa - tuloksen PITAA erota
    begin
      logic [16*256-1:0] result_n0, result_n1;
      counter_n = 8'd0;
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
      start2 <= 1'b1; @(posedge clk); start2 <= 1'b0;
      while (!done2) @(posedge clk);
      #1;
      result_n0 = f_out_2;

      counter_n = 8'd1;
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
      start2 <= 1'b1; @(posedge clk); start2 <= 1'b0;
      while (!done2) @(posedge clk);
      #1;
      result_n1 = f_out_2;

      if (result_n0 === result_n1) begin
        $display("FAIL: N=0 ja N=1 antoivat SAMAN tuloksen - N-laskuri ei vaikuta!");
        error_count++;
      end else $display("OK: N=0 ja N=1 antavat ERI tuloksen - N-laskuri vaikuttaa todistetusti");
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: PRF+SamplePolyCBD (%0d testitapausta + N-erottelutesti) tasmaa golden-malliin", case_count);
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
