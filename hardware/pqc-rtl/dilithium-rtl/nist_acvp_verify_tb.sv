// M5-DILITHIUM-001: NIST ACVP sigVer-testivektorin todennus. RTL
// Verify verrattuna SUORAAN NIST:n omaan viralliseen sigVer-FIPS204-
// KAT-vektoriin (usnistgov/ACVP-Server).

`timescale 1ns/1ps

module nist_acvp_verify_tb;

  localparam int K = 6;
  localparam int L = 5;
  localparam int OMEGA = 55;
  localparam int MSG_BYTES = 3;  // tama testitapaus: 2-tavuinen etuliite + 1-tavuinen viesti
  localparam int SIG_BYTES = 48+L*640+OMEGA+K;

  logic clk, reset, start, done, verify_ok;
  logic [8*(32+K*320)-1:0] pk_in;
  logic [8*SIG_BYTES-1:0] sig_in;
  logic [8*MSG_BYTES-1:0] m_in;

  always #5 clk = ~clk;

  pqc_dilithium_verify_top2 #(.K(K), .L(L), .OMEGA(OMEGA), .MSG_BYTES(MSG_BYTES)) dut (
    .clk(clk), .reset(reset), .start(start),
    .pk_in(pk_in), .sig_in(sig_in), .m_in(m_in),
    .done(done), .verify_ok(verify_ok)
  );

  int fh, scan_ok;
  logic [8*(32+K*320)-1:0] pk_val;
  logic [8*SIG_BYTES-1:0] sig_val;
  logic [8*MSG_BYTES-1:0] m_val;
  int expect_passed;
  int msg_bytes_check;

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/nist_acvp_verify_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", pk_val);
    scan_ok = $fscanf(fh, "%h\n", sig_val);
    scan_ok = $fscanf(fh, "%h\n", m_val);
    scan_ok = $fscanf(fh, "%d\n", expect_passed);
    scan_ok = $fscanf(fh, "%d\n", msg_bytes_check);
    $fclose(fh);

    pk_in = pk_val; sig_in = sig_val; m_in = m_val;

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    begin
      int wait_cycles;
      wait_cycles = 0;
      while (!done && wait_cycles < 150000) begin @(posedge clk); wait_cycles++; end
      if (!done) $display("FAIL: aikakatkaisu (%0d syklia)", wait_cycles);
      else $display("Valmis %0d syklin jalkeen, verify_ok=%0b (NIST:n oma testPassed=%0d)",
                     wait_cycles, verify_ok, expect_passed);
    end

    if (verify_ok == expect_passed[0]) begin
      $display("--------------------------------------------------");
      $display("PASS: RTL Verify tasmaa TAYDELLISESTI NIST:n omaan ACVP sigVer-KAT-vektoriin");
      $display("--------------------------------------------------");
    end else begin
      $display("--------------------------------------------------");
      $display("FAIL: RTL Verify EI tasmaa NIST:n omaan ACVP sigVer-KAT-vektoriin");
      $fatal(1);
    end

    $finish;
  end

endmodule
