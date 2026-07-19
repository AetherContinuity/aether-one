// M5-DILITHIUM-001 CI-regressio: Verify ajettuna kolmella
// RIIPPUMATTOMALLA, satunnaisella avainparilla (ei vain yhdella
// referenssivektorilla). Jokainen siemen tuottaa oman
// keygen+sign-parinsa dilithium-py:n omalla toteutuksella.

`timescale 1ns/1ps

module pqc_dilithium_verify_top2_multiseed_tb;

  localparam int K = 6;
  localparam int L = 5;
  localparam int OMEGA = 55;
  localparam int MSG_BYTES = 32;
  localparam int SIG_BYTES = 48+L*640+OMEGA+K;
  localparam int NUM_SEEDS = 3;

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

  int fh, scan_ok, error_count;
  logic [8*(32+K*320)-1:0] pk_val;
  logic [8*SIG_BYTES-1:0] sig_val;
  logic [8*MSG_BYTES-1:0] m_val;
  string fname;

  initial begin
    error_count = 0;
    clk = 0;

    for (int seed_idx = 0; seed_idx < NUM_SEEDS; seed_idx++) begin
      reset = 1; start = 0;
      fname = $sformatf("dilithium-rtl/verify_top2_test_vector_seed%0d.txt", seed_idx);
      fh = $fopen(fname, "r");
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
        while (!done && wait_cycles < 150000) begin @(posedge clk); wait_cycles++; end
        if (!done) begin
          $display("FAIL siemen %0d: aikakatkaisu", seed_idx);
          error_count++;
        end else if (!verify_ok) begin
          $display("FAIL siemen %0d: verify_ok=0 (odotettu 1), %0d syklia", seed_idx, wait_cycles);
          error_count++;
        end else begin
          $display("OK siemen %0d: verify_ok=1, %0d syklia", seed_idx, wait_cycles);
        end
      end

      // Palauta reset seuraavaa siementa varten
      @(posedge clk);
      reset = 1;
      @(posedge clk);
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: Verify hyvaksyi KAIKKI %0d riippumatonta avainparia", NUM_SEEDS);
    else begin $display("FAIL: %0d/%0d siementa epaonnistui", error_count, NUM_SEEDS); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
