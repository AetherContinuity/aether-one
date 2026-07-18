// M5-DILITHIUM-001 DK1-testi: RTL-RTL-round-trip. Oma forward-NTT-
// ydin syottaa omaa inverse-NTT-ydinta - tuloksen pitaisi tasmata
// TAYSIN alkuperaiseen syotteeseen, riippumatta dilithium-py:sta
// (tama testi ei vertaa mihinkaan ulkoiseen referenssiin - se
// tarkistaa etta oma forward+inverse-pari on itsekonsistentti).

`timescale 1ns/1ps

module pqc_dilithium_ntt_roundtrip_tb;

  localparam int CW = 23;

  logic clk, reset;
  logic fwd_start, fwd_done, inv_start, inv_done;
  logic [256*CW-1:0] original_coeffs;
  logic [256*CW-1:0] fwd_out, inv_out;

  always #5 clk = ~clk;

  pqc_dilithium_ntt_core fwd_dut (
    .clk(clk), .reset(reset), .start(fwd_start),
    .coeffs_in(original_coeffs), .done(fwd_done), .coeffs_out(fwd_out)
  );

  pqc_dilithium_ntt_inverse_core inv_dut (
    .clk(clk), .reset(reset), .start(inv_start),
    .coeffs_in(fwd_out), .done(inv_done), .coeffs_out(inv_out)
  );

  int fh, scan_ok;

  initial begin
    clk = 0; reset = 1; fwd_start = 0; inv_start = 0;

    fh = $fopen("dilithium-rtl/ntt_full_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", original_coeffs);
    $fclose(fh);

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);
    fwd_start <= 1'b1;
    @(posedge clk);
    fwd_start <= 1'b0;

    begin
      int wait_cycles;
      wait_cycles = 0;
      while (!fwd_done && wait_cycles < 20000) begin @(posedge clk); wait_cycles++; end
      $display("Forward-NTT valmis %0d syklin jalkeen", wait_cycles);
    end

    inv_start <= 1'b1;
    @(posedge clk);
    inv_start <= 1'b0;

    begin
      int wait_cycles;
      wait_cycles = 0;
      while (!inv_done && wait_cycles < 20000) begin @(posedge clk); wait_cycles++; end
      $display("Inverse-NTT valmis %0d syklin jalkeen", wait_cycles);
    end

    if (inv_out === original_coeffs) begin
      $display("PASS: RTL-RTL round-trip - NTT^-1(NTT(f)) == f taydellisesti (itsekonsistentti, ei ulkoista referenssia)");
    end else begin
      int diffs;
      diffs = 0;
      for (int i = 0; i < 256; i++) begin
        if (inv_out[i*CW+:CW] !== original_coeffs[i*CW+:CW]) diffs++;
      end
      $display("FAIL: %0d/256 kerrointa eroaa alkuperaisesta", diffs);
      $fatal(1);
    end

    $display("--------------------------------------------------");
    $finish;
  end

endmodule
