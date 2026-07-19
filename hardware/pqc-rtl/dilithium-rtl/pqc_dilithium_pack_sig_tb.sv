// M5-DILITHIUM-001 DK6 S8-testi: koko allekirjoituksen pakkaus
// todennus dilithium-py:n omaa _sign_internal()-tulosta vasten.

`timescale 1ns/1ps

module pqc_dilithium_pack_sig_tb;

  localparam int ZW = 24;
  localparam int OMEGA = 55;
  localparam int K = 6;
  localparam int L = 5;

  logic clk, reset, start, done;
  logic [383:0] c_tilde_in;
  logic [L*256*ZW-1:0] z_in_flat;
  logic [K*256-1:0] h_in_flat;
  logic [8*(48+L*640+OMEGA+K)-1:0] sig_out;

  always #5 clk = ~clk;

  pqc_dilithium_pack_sig #(.ZW(ZW), .OMEGA(OMEGA), .K(K), .L(L)) dut (
    .clk(clk), .reset(reset), .start(start),
    .c_tilde_in(c_tilde_in), .z_in_flat(z_in_flat), .h_in_flat(h_in_flat),
    .done(done), .sig_out(sig_out)
  );

  int fh, scan_ok;
  logic [383:0] c_tilde_val;
  logic [L*256*ZW-1:0] z_val;
  logic [K*256-1:0] h_val;
  logic [8*(48+L*640+OMEGA+K)-1:0] sig_expect;

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("dilithium-rtl/pack_sig_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", c_tilde_val);
    scan_ok = $fscanf(fh, "%h\n", z_val);
    scan_ok = $fscanf(fh, "%h\n", h_val);
    scan_ok = $fscanf(fh, "%h\n", sig_expect);
    $fclose(fh);

    c_tilde_in = c_tilde_val; z_in_flat = z_val; h_in_flat = h_val;

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    begin
      int wait_cycles;
      wait_cycles = 0;
      while (!done && wait_cycles < 3000) begin @(posedge clk); wait_cycles++; end
      if (!done) $display("FAIL: aikakatkaisu (%0d syklia)", wait_cycles);
      else $display("Valmis %0d syklin jalkeen", wait_cycles);
    end

    if (sig_out === sig_expect) begin
      $display("PASS: koko allekirjoituksen pakkaus (3309 tavua) tasmaa taydellisesti");
    end else begin
      int diffs;
      diffs = 0;
      for (int b = 0; b < 48+L*640+OMEGA+K; b++) begin
        if (sig_out[b*8+:8] !== sig_expect[b*8+:8]) diffs++;
      end
      $display("FAIL: %0d/%0d tavua eroaa", diffs, 48+L*640+OMEGA+K);
      $fatal(1);
    end

    $display("--------------------------------------------------");
    $finish;
  end

endmodule
