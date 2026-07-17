// M4-DECAPS-ORCH-001 Phase A -testi: verrataan m'-tulosta suoraan
// golden-referenssiin (vectors/mlkem_decaps_a_vectors.txt).

`timescale 1ns/1ps

module pqc_mlkem_decaps_a_core_tb;

  localparam int COEFF_W = 16;
  localparam int SPAD_AW = 9;
  localparam int K = 2;
  localparam int DU = 10;
  localparam int DV = 4;

  logic clk, reset, start, done;
  logic [8*768-1:0] c_in, dkPKE_in;
  logic [255:0] h_in;
  logic [255:0] m_prime_out, K_prime_out, r_prime_out;

  always #5 clk = ~clk;

  pqc_mlkem_decaps_a_core #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW), .K(K), .DU(DU), .DV(DV)) dut (
    .clk(clk), .reset(reset), .start(start),
    .c_in(c_in), .dkPKE_in(dkPKE_in), .h_in(h_in),
    .done(done), .m_prime_out(m_prime_out),
    .K_prime_out(K_prime_out), .r_prime_out(r_prime_out)
  );

  int fh, scan_ok, error_count, case_count;
  logic [8*768-1:0] dkPKE;
  logic [255:0] h_val;
  string tag;

  initial begin
    error_count = 0; case_count = 0;
    clk = 0; reset = 1; start = 0;

    fh = $fopen("vectors/mlkem_decaps_a_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", dkPKE);
    scan_ok = $fscanf(fh, "%h\n", h_val);
    dkPKE_in = dkPKE;
    h_in = h_val;

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);

    for (int tc = 0; tc < 3; tc++) begin
      logic [8*768-1:0] c_variant;
      logic [255:0] m_prime_expect, K_prime_expect, r_prime_expect;

      scan_ok = $fscanf(fh, "%s\n", tag);
      scan_ok = $fscanf(fh, "%h\n", c_variant);
      scan_ok = $fscanf(fh, "%h\n", m_prime_expect);
      scan_ok = $fscanf(fh, "%h\n", K_prime_expect);
      scan_ok = $fscanf(fh, "%h\n", r_prime_expect);

      c_in = c_variant;
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
          if (m_prime_out !== m_prime_expect) begin
            $display("FAIL %s: m' EI tasmaa (%0d syklia)", tag, wait_cycles);
            $display("  RTL:    %h", m_prime_out);
            $display("  golden: %h", m_prime_expect);
            error_count++;
          end else $display("OK %s: m' tasmaa taydellisesti golden-malliin (%0d syklia)", tag, wait_cycles);

          if (K_prime_out !== K_prime_expect) begin
            $display("FAIL %s: K' EI tasmaa", tag);
            error_count++;
          end else $display("OK %s: K' tasmaa taydellisesti golden-malliin", tag);

          if (r_prime_out !== r_prime_expect) begin
            $display("FAIL %s: r' EI tasmaa", tag);
            error_count++;
          end else $display("OK %s: r' tasmaa taydellisesti golden-malliin", tag);
        end
      end

      case_count++;
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
    end
    $fclose(fh);

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: Decaps Phase A (K-PKE.Decrypt) - m' tasmaa kaikille %0d tapaukselle", case_count);
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
