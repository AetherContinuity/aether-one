// M5-DILITHIUM-001: RTL Sign vs. NIST ACVP sigGen-FIPS204 (ML-DSA-65,
// tgId=10/tcId=139, deterministic, signatureInterface=internal,
// rnd=0). Testaa RTL Sign + pack_sig suoraan NIST:n omaa KAT-
// vektoria vasten (EI dilithium-py:n kautta).

`timescale 1ns/1ps

module sign_nist_acvp_tb;

  localparam int K = 6;
  localparam int L = 5;
  localparam int MSG_BYTES = 1;
  localparam int ZW = 24;
  localparam int OMEGA = 55;

  logic clk, reset, start, done;
  logic [255:0] rho_in, k_key_in, rnd_in;
  logic [511:0] tr_in;
  logic [L*256*23-1:0] s1_in_flat;
  logic [K*256*23-1:0] s2_in_flat, t0_in_flat;
  logic [8*MSG_BYTES-1:0] m_in;
  logic [L*256*ZW-1:0] z_out_flat;
  logic [K*256-1:0] h_out_flat;
  logic [383:0] c_tilde_out;
  logic [15:0] kappa_final_out;
  logic [7:0] iter_count_out;

  always #5 clk = ~clk;

  pqc_dilithium_sign_top2 #(.K(K), .L(L), .MSG_BYTES(MSG_BYTES)) sign_dut (
    .clk(clk), .reset(reset), .start(start),
    .rho_in(rho_in), .k_key_in(k_key_in), .tr_in(tr_in),
    .s1_in_flat(s1_in_flat), .s2_in_flat(s2_in_flat), .t0_in_flat(t0_in_flat),
    .m_in(m_in), .rnd_in(rnd_in),
    .done(done), .z_out_flat(z_out_flat), .h_out_flat(h_out_flat),
    .c_tilde_out(c_tilde_out), .kappa_final_out(kappa_final_out), .iter_count_out(iter_count_out)
  );

  logic packsig_start, packsig_done;
  logic [8*(48+L*640+OMEGA+K)-1:0] sig_out;
  pqc_dilithium_pack_sig #(.OMEGA(OMEGA), .K(K), .L(L)) packsig_dut (
    .clk(clk), .reset(reset), .start(packsig_start),
    .c_tilde_in(c_tilde_out), .z_in_flat(z_out_flat), .h_in_flat(h_out_flat),
    .done(packsig_done), .sig_out(sig_out)
  );

  int fh, scan_ok;
  logic [255:0] rho_val, k_key_val, rnd_val;
  logic [511:0] tr_val;
  logic [L*256*23-1:0] s1_val;
  logic [K*256*23-1:0] s2_val, t0_val;
  logic [8*MSG_BYTES-1:0] m_val;
  logic [8*(48+L*640+OMEGA+K)-1:0] sig_expect;

  initial begin
    clk = 0; reset = 1; start = 0; packsig_start = 0;

    fh = $fopen("dilithium-rtl/sign_nist_acvp_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", rho_val);
    scan_ok = $fscanf(fh, "%h\n", k_key_val);
    scan_ok = $fscanf(fh, "%h\n", tr_val);
    scan_ok = $fscanf(fh, "%h\n", s1_val);
    scan_ok = $fscanf(fh, "%h\n", s2_val);
    scan_ok = $fscanf(fh, "%h\n", t0_val);
    scan_ok = $fscanf(fh, "%h\n", m_val);
    scan_ok = $fscanf(fh, "%h\n", rnd_val);
    scan_ok = $fscanf(fh, "%h\n", sig_expect);
    $fclose(fh);

    rho_in = rho_val; k_key_in = k_key_val; tr_in = tr_val;
    s1_in_flat = s1_val; s2_in_flat = s2_val; t0_in_flat = t0_val;
    m_in = m_val; rnd_in = rnd_val;

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    begin
      int wait_cycles;
      wait_cycles = 0;
      while (!done && wait_cycles < 400000) begin @(posedge clk); wait_cycles++; end
      if (!done) begin $display("FAIL: Sign aikakatkaisu (%0d syklia)", wait_cycles); $fatal(1); end
      $display("Sign valmis %0d syklin jalkeen, kappa=%0d, iteraatioita=%0d", wait_cycles, kappa_final_out, iter_count_out);
    end

    @(posedge clk); packsig_start <= 1'b1;
    @(posedge clk); packsig_start <= 1'b0;
    wait (packsig_done);
    @(posedge clk);

    if (sig_out === sig_expect) begin
      $display("--------------------------------------------------");
      $display("PASS: RTL Sign tasmaa TAYDELLISESTI NIST ACVP sigGen-KAT-vektoriin (tgId=10, tcId=139)");
      $display("--------------------------------------------------");
    end else begin
      int diffs;
      diffs = 0;
      for (int b = 0; b < 48+L*640+OMEGA+K; b++) begin
        if (sig_out[b*8+:8] !== sig_expect[b*8+:8]) diffs++;
      end
      $display("FAIL: %0d/%0d tavua eroaa NIST-vektorista", diffs, 48+L*640+OMEGA+K);
      $fatal(1);
    end

    $finish;
  end

endmodule
