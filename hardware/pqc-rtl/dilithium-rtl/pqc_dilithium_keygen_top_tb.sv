// M5-DILITHIUM-001: koko ML-DSA-65.KeyGen_internal-huippumoduulin
// paasta-paahan-testi dilithium-py:n omaa _keygen_internal()-
// tulosta vasten.

`timescale 1ns/1ps

module pqc_dilithium_keygen_top_tb;

  localparam int K = 6;
  localparam int L = 5;

  logic clk, reset, start, done;
  logic [255:0] zeta_in;
  logic [8*(32+K*320)-1:0] ek_out;
  logic [8*(32+32+64+L*128+K*128+K*416)-1:0] dk_out;

  always #5 clk = ~clk;

  pqc_dilithium_keygen_top #(.K(K), .L(L)) dut (
    .clk(clk), .reset(reset), .start(start),
    .zeta_in(zeta_in), .done(done),
    .ek_out(ek_out), .dk_out(dk_out)
  );

  int fh, scan_ok;
  logic [255:0] zeta_val;
  logic [8*(32+K*320)-1:0] ek_expect;
  logic [8*(32+32+64+L*128+K*128+K*416)-1:0] dk_expect;

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/keygen_top_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", zeta_val);
    scan_ok = $fscanf(fh, "%h\n", ek_expect);
    scan_ok = $fscanf(fh, "%h\n", dk_expect);
    $fclose(fh);

    zeta_in = zeta_val;

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    begin
      int wait_cycles;
      wait_cycles = 0;
      while (!done && wait_cycles < 200000) begin @(posedge clk); wait_cycles++; end
      if (!done) $display("FAIL: aikakatkaisu (%0d syklia)", wait_cycles);
      else $display("Valmis %0d syklin jalkeen", wait_cycles);
    end

    if (ek_out === ek_expect) $display("OK: ek (1952 tavua) tasmaa taydellisesti");
    else begin $display("FAIL: ek EI tasmaa"); end

    if (dk_out === dk_expect) $display("OK: dk (4032 tavua) tasmaa taydellisesti");
    else begin $display("FAIL: dk EI tasmaa"); end

    if (ek_out === ek_expect && dk_out === dk_expect) begin
      $display("--------------------------------------------------");
      $display("PASS: KOKO ML-DSA-65.KeyGen_internal TOIMII PAASTA PAAHAN");
      $display("--------------------------------------------------");
    end else begin
      $display("--------------------------------------------------");
      $display("FAIL: KeyGen ei tasmaa");
      $fatal(1);
    end

    $finish;
  end

endmodule
