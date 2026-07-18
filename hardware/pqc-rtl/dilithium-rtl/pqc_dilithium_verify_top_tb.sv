// M5-DILITHIUM-001: koko ML-DSA-65.Verify_internal-huippumoduulin
// paasta-paahan-testi, kayttaen dilithium-py:n omaa keygen+sign-
// paria aidon, kelvollisen allekirjoituksen tuottamiseen.

`timescale 1ns/1ps

module pqc_dilithium_verify_top_tb;

  localparam int K = 6;
  localparam int L = 5;
  localparam int MSG_BYTES = 32;
  localparam int SIG_BYTES = 48+L*640+55+K;

  logic clk, reset, start, done, verify_ok;
  logic [8*(32+K*320)-1:0] pk_in;
  logic [8*SIG_BYTES-1:0] sig_in;
  logic [8*MSG_BYTES-1:0] m_in;

  always #5 clk = ~clk;

  pqc_dilithium_verify_top #(.K(K), .L(L), .MSG_BYTES(MSG_BYTES)) dut (
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

    fh = $fopen("dilithium-rtl/verify_top_test_vector.txt", "r");
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
      while (!done && wait_cycles < 600000) begin @(posedge clk); wait_cycles++; end
      if (!done) $display("FAIL: aikakatkaisu (%0d syklia)", wait_cycles);
      else $display("Valmis %0d syklin jalkeen", wait_cycles);
    end

    $display("verify_ok: %0b (odotettu: 1, koska allekirjoitus on aito)", verify_ok);

    if (verify_ok) begin
      $display("--------------------------------------------------");
      $display("PASS: KOKO ML-DSA-65.Verify_internal TOIMII PAASTA PAAHAN");
      $display("--------------------------------------------------");
    end else begin
      $display("--------------------------------------------------");
      $display("FAIL: Verify EI hyvaksynyt aitoa allekirjoitusta");
      $fatal(1);
    end

    $finish;
  end

endmodule
