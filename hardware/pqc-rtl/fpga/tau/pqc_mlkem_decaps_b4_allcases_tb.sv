// M4-DECAPS-ORCH-001 Phase B4 -testi: kaikki kolme jaadytettya
// testitapausta (valid, byte_corrupted, bit_corrupted) - tarkistaa
// VAIN lopputuloksen (c', match, K_final), koska valivaiheet on jo
// erikseen todennettu (pqc_mlkem_decaps_b1_core_tb.sv).

`timescale 1ns/1ps

module pqc_mlkem_decaps_b4_allcases_tb;

  localparam int COEFF_W = 16;
  localparam int K = 2;

  logic clk, reset, start, done;
  logic [8*800-1:0] ek_in;
  logic [255:0] r_prime_in, m_prime_in;
  logic [4*256*COEFF_W-1:0] A_out_flat;
  logic [K*256*COEFF_W-1:0] y_vec_out_flat, y_hat_out_flat, e1_vec_out_flat, u_acc_out_flat, u_vec_out_flat;
  logic [256*COEFF_W-1:0] e2_poly_out, v_acc_out, v_poly_out;
  logic [8*768-1:0] c_prime_out;
  logic [8*768-1:0] c_in;
  logic [255:0] z_in, K_prime_in;
  logic match_out;
  logic [255:0] K_final_out;

  always #5 clk = ~clk;

  pqc_mlkem_decaps_b1_core #(.COEFF_W(COEFF_W), .K(K)) dut (
    .clk(clk), .reset(reset), .start(start),
    .ek_in(ek_in), .r_prime_in(r_prime_in), .m_prime_in(m_prime_in),
    .c_in(c_in), .z_in(z_in), .K_prime_in(K_prime_in),
    .done(done), .A_out_flat(A_out_flat),
    .y_vec_out_flat(y_vec_out_flat), .y_hat_out_flat(y_hat_out_flat),
    .e1_vec_out_flat(e1_vec_out_flat), .e2_poly_out(e2_poly_out),
    .u_acc_out_flat(u_acc_out_flat), .v_acc_out(v_acc_out),
    .u_vec_out_flat(u_vec_out_flat), .v_poly_out(v_poly_out),
    .c_prime_out(c_prime_out),
    .match_out(match_out), .K_final_out(K_final_out)
  );

  int fh, scan_ok, error_count, case_count;
  logic [8*800-1:0] ek;
  logic [255:0] z_seed;
  string tag;

  initial begin
    error_count = 0; case_count = 0;
    clk = 0; reset = 1; start = 0;

    fh = $fopen("vectors/mlkem_decaps_b_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", ek);
    scan_ok = $fscanf(fh, "%h\n", z_seed);
    ek_in = ek; z_in = z_seed;

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);

    for (int tc = 0; tc < 3; tc++) begin
      logic [255:0] m_prime, r_prime, K_prime_expect;
      logic [8*768-1:0] c_variant, c_prime_expect;
      int match_expect;
      logic [255:0] K_final_expect;

      scan_ok = $fscanf(fh, "%s\n", tag);
      scan_ok = $fscanf(fh, "%h\n", m_prime);
      scan_ok = $fscanf(fh, "%h\n", r_prime);
      scan_ok = $fscanf(fh, "%h\n", K_prime_expect);
      scan_ok = $fscanf(fh, "%h\n", c_variant);
      scan_ok = $fscanf(fh, "%h\n", c_prime_expect);
      scan_ok = $fscanf(fh, "%d\n", match_expect);
      scan_ok = $fscanf(fh, "%h\n", K_final_expect);

      m_prime_in = m_prime;
      r_prime_in = r_prime;
      c_in = c_variant;
      K_prime_in = K_prime_expect;

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
        if (!done) begin
          $display("FAIL %s: aikakatkaisu (%0d syklia)", tag, wait_cycles);
          error_count++;
        end else begin
          if (c_prime_out !== c_prime_expect) begin
            $display("FAIL %s: c' EI tasmaa", tag);
            error_count++;
          end else $display("OK %s: c' tasmaa taydellisesti (%0d syklia)", tag, wait_cycles);

          if ((match_out ? 1 : 0) !== match_expect) begin
            $display("FAIL %s: match EI tasmaa (RTL=%0b, golden=%0d)", tag, match_out, match_expect);
            error_count++;
          end else $display("OK %s: match tasmaa (%0d)", tag, match_expect);

          if (K_final_out !== K_final_expect) begin
            $display("FAIL %s: K_final EI tasmaa", tag);
            error_count++;
          end else $display("OK %s: K_final (%s) tasmaa taydellisesti",
                              tag, match_out ? "normaali K'" : "implisiittinen hylkays J(z||c)");
        end
      end

      case_count++;
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
    end
    $fclose(fh);

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: Decaps Phase B4 (FO-valinta) tasmaa golden-malliin kaikille %0d tapaukselle", case_count);
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
