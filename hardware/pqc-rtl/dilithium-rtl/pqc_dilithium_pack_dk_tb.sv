// M5-DILITHIUM-001 DK4-testi: koko dk-kokoonpanon (rho||K||tr||s1||
// s2||t0) todennus dilithium-py:n omaa _pack_sk()-tulosta vasten.

`timescale 1ns/1ps

module pqc_dilithium_pack_dk_tb;

  localparam int K = 6;
  localparam int L = 5;

  logic clk, reset, start, done;
  logic [255:0] rho_in, K_in;
  logic [8*(32+K*320)-1:0] ek_in;
  logic [L*8*128-1:0] s1_packed_in;
  logic [K*8*128-1:0] s2_packed_in;
  logic [K*256*13-1:0] t0_packed_in;
  logic [8*(32+32+64+L*128+K*128+K*416)-1:0] dk_out;

  always #5 clk = ~clk;

  pqc_dilithium_pack_dk #(.K(K), .L(L)) dut (
    .clk(clk), .reset(reset), .start(start),
    .rho_in(rho_in), .K_in(K_in), .ek_in(ek_in),
    .s1_packed_in(s1_packed_in), .s2_packed_in(s2_packed_in), .t0_packed_in(t0_packed_in),
    .done(done), .dk_out(dk_out)
  );

  int fh, scan_ok;
  logic [255:0] rho_val, K_val;
  logic [8*(32+K*320)-1:0] ek_val;
  logic [L*8*128-1:0] s1_packed_val;
  logic [K*8*128-1:0] s2_packed_val;
  logic [K*256*13-1:0] t0_packed_val;
  logic [8*(32+32+64+L*128+K*128+K*416)-1:0] dk_expect;

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/pack_dk_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", rho_val);
    scan_ok = $fscanf(fh, "%h\n", K_val);
    scan_ok = $fscanf(fh, "%h\n", ek_val);
    scan_ok = $fscanf(fh, "%h\n", s1_packed_val);
    scan_ok = $fscanf(fh, "%h\n", s2_packed_val);
    scan_ok = $fscanf(fh, "%h\n", t0_packed_val);
    scan_ok = $fscanf(fh, "%h\n", dk_expect);
    $fclose(fh);

    rho_in = rho_val; K_in = K_val; ek_in = ek_val;
    s1_packed_in = s1_packed_val; s2_packed_in = s2_packed_val; t0_packed_in = t0_packed_val;

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    begin
      int wait_cycles;
      wait_cycles = 0;
      while (!done && wait_cycles < 5000) begin @(posedge clk); wait_cycles++; end
      if (!done) $display("FAIL: aikakatkaisu (%0d syklia)", wait_cycles);
      else $display("Valmis %0d syklin jalkeen", wait_cycles);
    end

    if (dk_out === dk_expect) begin
      $display("PASS: koko dk (4032 tavua) tasmaa taydellisesti dilithium-py:n _pack_sk()-tulokseen");
    end else begin
      int diffs;
      diffs = 0;
      for (int b = 0; b < 4032; b++) begin
        if (dk_out[b*8+:8] !== dk_expect[b*8+:8]) diffs++;
      end
      $display("FAIL: %0d/4032 tavua eroaa", diffs);
      $fatal(1);
    end

    $display("--------------------------------------------------");
    $finish;
  end

endmodule
