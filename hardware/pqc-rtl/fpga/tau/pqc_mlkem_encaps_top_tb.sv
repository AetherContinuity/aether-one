// M4-ENCAPS-ORCH-001: koko Encaps-huippumoduulin testi tuoreella,
// riippumattomalla testivektorilla (mlkem_keygen_internal ->
// mlkem_encaps_internal).

`timescale 1ns/1ps

module pqc_mlkem_encaps_top_tb;

  localparam int COEFF_W = 16;
  localparam int K = 2;

  logic clk, reset, start, done;
  logic [8*800-1:0] ek_in;
  logic [255:0] m_in;
  logic [255:0] K_out;
  logic [8*768-1:0] c_out;

  always #5 clk = ~clk;

  pqc_mlkem_encaps_top #(.COEFF_W(COEFF_W), .K(K)) dut (
    .clk(clk), .reset(reset), .start(start),
    .ek_in(ek_in), .m_in(m_in),
    .done(done), .K_out(K_out), .c_out(c_out)
  );

  int fh, scan_ok;
  logic [8*800-1:0] ek;
  logic [255:0] m_msg, K_expect;
  logic [8*768-1:0] c_expect;

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("fpga/tau/encaps_top_e2e_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", ek);
    scan_ok = $fscanf(fh, "%h\n", m_msg);
    scan_ok = $fscanf(fh, "%h\n", K_expect);
    scan_ok = $fscanf(fh, "%h\n", c_expect);
    $fclose(fh);

    ek_in = ek; m_in = m_msg;

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    begin
      int wait_cycles;
      wait_cycles = 0;
      while (!done && wait_cycles < 30000) begin
        @(posedge clk);
        wait_cycles++;
      end
      if (!done) $display("FAIL: aikakatkaisu (%0d syklia)", wait_cycles);
      else $display("Valmis %0d syklin jalkeen", wait_cycles);
    end

    if (K_out === K_expect) $display("OK: K tasmaa taydellisesti golden-malliin");
    else begin
      $display("FAIL: K EI tasmaa");
      $display("  RTL:    %h", K_out);
      $display("  golden: %h", K_expect);
    end

    if (c_out === c_expect) $display("PASS: c tasmaa taydellisesti golden-malliin");
    else begin
      int diffs;
      diffs = 0;
      for (int b = 0; b < 768; b++) if (c_out[b*8+:8] !== c_expect[b*8+:8]) diffs++;
      $display("FAIL: c EI tasmaa - %0d/768 tavua eroaa", diffs);
      $fatal(1);
    end

    $display("--------------------------------------------------");
    $display("PASS: koko Encaps-huippumoduuli - K ja c tasmaavat taydellisesti riippumattomaan testivektoriin");
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
