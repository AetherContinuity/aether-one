// M5-DILITHIUM-001: Sign-CI-regressio: koko Sign_internal ajettuna
// KOLMELLA riippumattomalla avainparilla/siemenella (ei vain yhdella
// referenssivektorilla). Kukin siemen valittu niin etta kappa=0
// onnistuu ensimmaisella yrityksella (hallittava simulointiaika).

`timescale 1ns/1ps

module pqc_dilithium_sign_top2_multiseed_tb;

  localparam int K = 6;
  localparam int L = 5;
  localparam int MSG_BYTES = 30;
  localparam int ZW = 24;
  localparam int NUM_SEEDS = 3;

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

  pqc_dilithium_sign_top2 #(.K(K), .L(L), .MSG_BYTES(MSG_BYTES)) dut (
    .clk(clk), .reset(reset), .start(start),
    .rho_in(rho_in), .k_key_in(k_key_in), .tr_in(tr_in),
    .s1_in_flat(s1_in_flat), .s2_in_flat(s2_in_flat), .t0_in_flat(t0_in_flat),
    .m_in(m_in), .rnd_in(rnd_in),
    .done(done), .z_out_flat(z_out_flat), .h_out_flat(h_out_flat),
    .c_tilde_out(c_tilde_out), .kappa_final_out(kappa_final_out), .iter_count_out(iter_count_out)
  );

  int fh, scan_ok, error_count;
  logic [255:0] rho_val, k_key_val, rnd_val;
  logic [511:0] tr_val;
  logic [L*256*23-1:0] s1_val;
  logic [K*256*23-1:0] s2_val, t0_val;
  logic [8*MSG_BYTES-1:0] m_val;
  logic [383:0] c_tilde_expect;
  logic [L*256*ZW-1:0] z_expect;
  logic [K*256-1:0] h_expect;
  string fname;

  initial begin
    clk = 0;
    error_count = 0;

    for (int seed_idx = 0; seed_idx < NUM_SEEDS; seed_idx++) begin
      reset = 1; start = 0;
      fname = $sformatf("dilithium-rtl/sign_top2_test_vector_seed%0d.txt", seed_idx);
      fh = $fopen(fname, "r");
      scan_ok = $fscanf(fh, "%h\n", rho_val);
      scan_ok = $fscanf(fh, "%h\n", k_key_val);
      scan_ok = $fscanf(fh, "%h\n", tr_val);
      scan_ok = $fscanf(fh, "%h\n", s1_val);
      scan_ok = $fscanf(fh, "%h\n", s2_val);
      scan_ok = $fscanf(fh, "%h\n", t0_val);
      scan_ok = $fscanf(fh, "%h\n", m_val);
      scan_ok = $fscanf(fh, "%h\n", rnd_val);
      scan_ok = $fscanf(fh, "%h\n", c_tilde_expect);
      scan_ok = $fscanf(fh, "%h\n", z_expect);
      scan_ok = $fscanf(fh, "%h\n", h_expect);
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
        if (!done) begin
          $display("FAIL siemen %0d: aikakatkaisu", seed_idx);
          error_count++;
        end else if (c_tilde_out !== c_tilde_expect || z_out_flat !== z_expect || h_out_flat !== h_expect) begin
          $display("FAIL siemen %0d: tulokset EIVAT tasmaa (c_tilde=%0b z=%0b h=%0b), %0d syklia",
                    seed_idx, c_tilde_out===c_tilde_expect, z_out_flat===z_expect, h_out_flat===h_expect, wait_cycles);
          error_count++;
        end else begin
          $display("OK siemen %0d: KAIKKI tasmaavat (c_tilde,z,h), kappa=%0d, iteraatioita=%0d, %0d syklia",
                    seed_idx, kappa_final_out, iter_count_out, wait_cycles);
        end
      end

      @(posedge clk);
      reset = 1;
      @(posedge clk);
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: Sign_internal tasmaa KAIKILLA %0d riippumattomalla siemenella", NUM_SEEDS);
    else begin $display("FAIL: %0d/%0d siementa epaonnistui", error_count, NUM_SEEDS); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
