// M5-DILITHIUM-001: koko ML-DSA-65.Verify_internal:n paasta-paahan-
// testi aidolla dilithium-py:n omalla allekirjoituksella.

`timescale 1ns/1ps

module pqc_dilithium_verify_top2_tb;

  localparam int K = 6;
  localparam int L = 5;
  localparam int OMEGA = 55;
  localparam int MSG_BYTES = 36;
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

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/verify_top2_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", pk_val);
    scan_ok = $fscanf(fh, "%h\n", sig_val);
    scan_ok = $fscanf(fh, "%h\n", m_val);
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
      while (!done && wait_cycles < 300000) begin @(posedge clk); wait_cycles++; end
      if (!done) $display("FAIL: aikakatkaisu (%0d syklia)", wait_cycles);
      else $display("Valmis %0d syklin jalkeen, verify_ok=%0b (odotettu: 1)", wait_cycles, verify_ok);
    end

    if (verify_ok) begin
      $display("--------------------------------------------------");
      $display("PASS: KOKO ML-DSA-65.Verify_internal HYVAKSYI AIDON ALLEKIRJOITUKSEN");
      $display("--------------------------------------------------");
    end else begin
      $display("--------------------------------------------------");
      $display("FAIL: Verify EI hyvaksynyt aitoa allekirjoitusta");
      $fatal(1);
    end

    $finish;
  end

endmodule
