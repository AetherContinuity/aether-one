// M5-DILITHIUM-001: VAIHEISTETTU functional-flow, Vaihe 3/3: Verify.
//
// ek.txt (Vaihe 1) + sig.txt (Vaihe 2) + msg -> RTL Verify ->
//   verify_ok (PASS/FAIL)
//
// Ajetaan ITSENAISENA prosessina - EI riipu Vaihe 1:n eika Vaihe 2:n
// omista simulaatioprosesseista, vain niiden TIEDOSTOTULOSTEISTA.
// Tama on VIIMEINEN lenkki functional flow'ssa: todistaa etta RTL
// Sign:n tuottama allekirjoitus HYVAKSYTAAN RTL Verify:lla, ilman
// Pythonia missaan valissa (paitsi msg-argumentin manuaalisena
// syotteena, joka TAYTYY tasmata Vaihe 2:n oman kanssa).

`timescale 1ns/1ps

module stage3_verify_tb;

  localparam int K = 6;
  localparam int L = 5;
  localparam int OMEGA = 55;
  localparam int MSG_BYTES = 30;

  logic clk, reset, start, done, verify_ok;
  logic [8*(32+K*320)-1:0] ek_in;
  logic [8*(48+L*640+OMEGA+K)-1:0] sig_in;
  logic [8*MSG_BYTES-1:0] m_in;

  always #5 clk = ~clk;

  pqc_dilithium_verify_top2 #(.K(K), .L(L), .OMEGA(OMEGA), .MSG_BYTES(MSG_BYTES)) dut (
    .clk(clk), .reset(reset), .start(start),
    .pk_in(ek_in), .sig_in(sig_in), .m_in(m_in),
    .done(done), .verify_ok(verify_ok)
  );

  int ekfh, sigfh;

  initial begin
    clk = 0; reset = 1; start = 0;

    ekfh = $fopen("dilithium-rtl/staged/ek.txt", "r");
    void'($fscanf(ekfh, "%h\n", ek_in));
    $fclose(ekfh);

    sigfh = $fopen("dilithium-rtl/staged/sig.txt", "r");
    void'($fscanf(sigfh, "%h\n", sig_in));
    $fclose(sigfh);

    if (!$value$plusargs("msg=%h", m_in)) begin
      m_in = 240'h1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100; // TAYTYY tasmata Vaihe 2:n omaan
    end

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk); start <= 1'b1;
    @(posedge clk); start <= 1'b0;
    while (!done) @(posedge clk);

    $display("--------------------------------------------------");
    if (verify_ok) begin
      $display("PASS: Vaihe 3 (Verify) - RTL Sign:n tuottama allekirjoitus HYVAKSYTTIIN RTL Verify:lla");
      $display("KOKO FUNCTIONAL FLOW (KeyGen->Sign->Verify, tiedostopohjainen) LAPI ILMAN PYTHONIA");
    end else begin
      $display("FAIL: Verify HYLKASI RTL Sign:n tuottaman allekirjoituksen");
      $fatal(1);
    end
    $display("--------------------------------------------------");

    $finish;
  end

endmodule
