// decaps_toggle_tb.sv
//
// Soveltaa validoitua toggle-count-proxy-menetelmaa (ks.
// toggle-proxy/TOGGLE-PROXY-VALIDATION.md) oikeaan kohteeseen:
// pqc_mlkem_decaps_top.sv, saman-avaimen valid/rejection-parilla
// (sama data kuin syklimittauksessa, ks. decaps_samekey_vectors.txt).
//
// Ajaa YHDEN tapauksen kerrallaan (indeksi plusargilla), dumpaten
// VCD:n. Kytkennat lasketaan JALKIKATEEN count_toggles.py:lla,
// rajattuna `decaps_b`-scopen (Phase B: decaps_b1_core, sisaltaa
// match_out/K_final_out-logiikan) sisaisiin/ulostulosignaaleihin.

`timescale 1ns/1ps

module decaps_toggle_tb;

  localparam int K = 2;

  logic clk, reset, start, done;
  logic [8*768-1:0] c_in;
  logic [8*1632-1:0] dk_in;
  logic [255:0] K_final_out;
  logic match_out;

  always #5 clk = ~clk;

  pqc_mlkem_decaps_top #(.K(K)) dut (
    .clk(clk), .reset(reset), .start(start),
    .c_in(c_in), .dk_in(dk_in),
    .done(done), .K_final_out(K_final_out), .match_out(match_out)
  );

  int fh, scan_ok, num_vectors, tc_id, rejection_expect, case_idx;
  logic [8*1632-1:0] dk_val;
  logic [8*768-1:0] c_val;
  logic [255:0] k_expect;
  string vcd_name;

  initial begin
    clk = 0; reset = 1; start = 0;

    if (!$value$plusargs("case_idx=%d", case_idx)) case_idx = 0;
    if (!$value$plusargs("vcd_name=%s", vcd_name)) vcd_name = "decaps_toggle.vcd";

    fh = $fopen("fpga/tau/decaps_samekey_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%d\n", num_vectors);
    for (int i = 0; i <= case_idx; i++) begin
      scan_ok = $fscanf(fh, "%d %d\n", tc_id, rejection_expect);
      scan_ok = $fscanf(fh, "%h\n", dk_val);
      scan_ok = $fscanf(fh, "%h\n", c_val);
      scan_ok = $fscanf(fh, "%h\n", k_expect);
    end
    $fclose(fh);

    dk_in = dk_val; c_in = c_val;

    $dumpfile(vcd_name);
    $dumpvars(0, decaps_toggle_tb);

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk); start <= 1'b1;
    @(posedge clk); start <= 1'b0;
    while (!done) @(posedge clk);
    @(posedge clk);

    $display("tcId=%0d rejection_expect=%0d K_tasmaa=%b match_out=%b",
              tc_id, rejection_expect, (K_final_out === k_expect), match_out);
    $finish;
  end

endmodule
