// M5-DILITHIUM-001: NIST ACVP -testivektorien todennus. RTL KeyGen
// verrattuna SUORAAN NIST:n omaan viralliseen keyGen-FIPS204-KAT-
// vektoriin (usnistgov/ACVP-Server, ei dilithium-py:n kautta).

`timescale 1ns/1ps

module nist_acvp_keygen_tb;

  localparam int K = 6;
  localparam int L = 5;

  logic clk, reset, start, done;
  logic [255:0] zeta_in;
  logic [8*(32+K*320)-1:0] ek_out;
  logic [8*(32+32+64+L*128+K*128+K*416)-1:0] dk_out;

  always #5 clk = ~clk;

  pqc_dilithium_keygen_top #(.K(K), .L(L)) dut (
    .clk(clk), .reset(reset), .start(start),
    .zeta_in(zeta_in), .done(done), .ek_out(ek_out), .dk_out(dk_out)
  );

  int fh, scan_ok;
  logic [255:0] seed_val;
  logic [8*(32+K*320)-1:0] pk_expect;
  logic [8*(32+32+64+L*128+K*128+K*416)-1:0] sk_expect;

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/nist_acvp_keygen_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", seed_val);
    scan_ok = $fscanf(fh, "%h\n", pk_expect);
    scan_ok = $fscanf(fh, "%h\n", sk_expect);
    $fclose(fh);

    zeta_in = seed_val;

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

    if (ek_out === pk_expect) $display("OK: ek (pk) tasmaa NIST ACVP -vektoriin");
    else $display("FAIL: ek (pk) EI tasmaa NIST ACVP -vektoriin");

    if (dk_out === sk_expect) $display("OK: dk (sk) tasmaa NIST ACVP -vektoriin");
    else $display("FAIL: dk (sk) EI tasmaa NIST ACVP -vektoriin");

    if (ek_out === pk_expect && dk_out === sk_expect) begin
      $display("--------------------------------------------------");
      $display("PASS: RTL KeyGen tasmaa TAYDELLISESTI NIST:n omaan ACVP-KAT-vektoriin");
      $display("--------------------------------------------------");
    end else begin
      $display("--------------------------------------------------");
      $display("FAIL: RTL KeyGen EI tasmaa NIST:n omaan ACVP-KAT-vektoriin");
      $fatal(1);
    end

    $finish;
  end

endmodule
