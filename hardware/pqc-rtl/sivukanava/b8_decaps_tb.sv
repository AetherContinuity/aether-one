// b8_decaps_tb.sv: B8-otoksen ajoitusmittaus (ks. B8-ENNAKKO.md).
//
// iverilog ... -P b8_decaps_tb.K=2|3
// +VEC=<sivukanava/gen_b8_vectors.py:n tiedosto>
// +ONLY=<i>  (valinnainen) ajaa vain tapauksen i ja kirjoittaa
// +VCD=<tiedosto> -tiedostoon decaps_b-scopen signaalit (syvyys 1).
//
// Tulostaa per tapaus rivin:
//   B8 tcId muunnelma phaseA phaseB kokonais K_ok match match_odotus
// phaseA = sykli, jolla dut.phaseA_done nousee; phaseB = sykli, jolla
// dut.phaseB_done nousee, miinus phaseA; kokonais = sykli, jolla done.
// Jokainen tapaus ajetaan resetin jalkeen.

`timescale 1ns/1ps

module b8_decaps_tb;

  parameter int K = 2;
  localparam int DK_BYTES = 768*K + 96;
  localparam int C_BYTES  = 32*(10*K + 4);
  localparam int MAX_CYCLES = 200000;

  logic clk = 0, reset = 1, start = 0, done, match_out;
  logic [8*C_BYTES-1:0] c_in;
  logic [8*DK_BYTES-1:0] dk_in;
  logic [255:0] K_final_out;
  always #5 clk = ~clk;

  pqc_mlkem_decaps_top #(.K(K)) dut (
    .clk(clk), .reset(reset), .start(start), .c_in(c_in), .dk_in(dk_in),
    .done(done), .K_final_out(K_final_out), .match_out(match_out));

  string vec_path, vcd_path;
  int fh, n, only, tc, vid, mexp, nread, cyc, pa, pb, fails;
  logic [8*DK_BYTES-1:0] x_dk;
  logic [8*C_BYTES-1:0]  x_c;
  logic [255:0] x_K;
  logic fin;

  initial begin
    if (!$value$plusargs("VEC=%s", vec_path)) begin $display("FAIL: +VEC puuttuu"); $fatal(1); end
    if (!$value$plusargs("ONLY=%d", only)) only = -1;
    fh = $fopen(vec_path, "r");
    if (fh == 0) begin $display("FAIL: %0s ei auennut", vec_path); $fatal(1); end
    if ($fscanf(fh, "%d\n", n) != 1) begin $display("FAIL: tapausmaara puuttuu"); $fatal(1); end
    if (only >= 0) begin
      if (!$value$plusargs("VCD=%s", vcd_path)) begin $display("FAIL: +VCD puuttuu"); $fatal(1); end
    end
    fails = 0;

    for (int i = 0; i < n; i++) begin
      nread  = $fscanf(fh, "%d %d %d\n", tc, vid, mexp);
      nread += $fscanf(fh, "%h\n", x_dk);
      nread += $fscanf(fh, "%h\n", x_c);
      nread += $fscanf(fh, "%h\n", x_K);
      if (nread != 6) begin $display("FAIL: tapaus %0d: %0d/6 kenttaa", i, nread); $fatal(1); end
      if (only < 0 || i == only) begin

        dk_in = x_dk; c_in = x_c;
        reset = 1;
        repeat (3) @(posedge clk);
        if (only >= 0) begin
          $dumpfile(vcd_path);
          $dumpvars(1, dut.decaps_b);
        end
        reset = 0;
        @(posedge clk); start <= 1'b1;
        @(posedge clk); start <= 1'b0;
        cyc = 0; pa = -1; pb = -1;
        while (!done && cyc < MAX_CYCLES) begin
          @(posedge clk); cyc++;
          if (pa < 0 && dut.phaseA_done) pa = cyc;
          if (pb < 0 && dut.phaseB_done) pb = cyc;
        end
        fin = done;
        @(posedge clk);
        if (!fin || pa < 0 || pb < 0) begin
          $display("FAIL: tapaus %0d ei valmistunut", i); fails++;
        end
        $display("B8 %0d %0d %0d %0d %0d %0d %0d %0d", tc, vid, pa, pb - pa, cyc,
                 (K_final_out === x_K), match_out, mexp);
        if (only >= 0) begin $dumpflush; $dumpoff; end
      end
    end
    $fclose(fh);
    if (fails == 0) $display("B8-AJO VALMIS");
    else            $display("FAIL: B8-ajossa %0d keskeytynytta tapausta", fails);
    $finish;
  end

endmodule
