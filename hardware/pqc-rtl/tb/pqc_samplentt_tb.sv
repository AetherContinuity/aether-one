// pqc_samplentt_tb.sv
// M3 Issue #15 Vaihe 2 (loppuunsaattaminen): koko SampleNTT-moduulin
// (XOF+hylkaysnaytteenotto) testipenkki.

`timescale 1ns/1ps

module pqc_samplentt_tb;

  localparam int XOF_BYTES = 1008;

  logic clk, reset, start, done, error_exhausted;
  logic [255:0] rho;
  logic [7:0] byte_j, byte_i;
  logic [16*256-1:0] a_hat;
  logic [15:0] accepted_count, rejected_count, xof_bytes_consumed;

  pqc_samplentt #(.XOF_BYTES(XOF_BYTES)) dut (
    .clk(clk), .reset(reset), .start(start),
    .rho(rho), .byte_j(byte_j), .byte_i(byte_i),
    .a_hat(a_hat), .accepted_count(accepted_count), .rejected_count(rejected_count),
    .xof_bytes_consumed(xof_bytes_consumed), .done(done), .error_exhausted(error_exhausted)
  );

  always #5 clk = ~clk;

  int fh, scan_ok, error_count, case_count, jv, iv;
  string name;
  int expect_accepted, expect_rejected, expect_xof_bytes;
  logic [16*256-1:0] a_hat_expect;

  initial begin
    error_count = 0; case_count = 0;
    clk = 0; reset = 1; start = 0; rho = '0; byte_j = 0; byte_i = 0;

    fh = $fopen("vectors/samplentt_full_vectors.txt", "r");

    for (int tc = 0; tc < 5; tc++) begin
      scan_ok = $fscanf(fh, "%s %d %d %d %d %d\n", name, jv, iv, expect_accepted, expect_rejected, expect_xof_bytes);
      byte_j = jv[7:0];
      byte_i = iv[7:0];
      scan_ok = $fscanf(fh, "%h\n", rho);
      scan_ok = $fscanf(fh, "%h\n", a_hat_expect);

      repeat (3) @(posedge clk);
      reset = 0;
      @(posedge clk);
      start <= 1'b1;
      @(posedge clk);
      start <= 1'b0;

      while (!done) @(posedge clk);
      #1;

      if (error_exhausted) begin
        $display("FAIL %s: XOF-puskuri loppui kesken (ei odotettu)", name);
        error_count++;
      end else if (a_hat !== a_hat_expect) begin
        $display("FAIL %s: a_hat poikkeaa golden-mallista", name);
        error_count++;
      end else if (accepted_count !== expect_accepted[15:0] || rejected_count !== expect_rejected[15:0] ||
                   xof_bytes_consumed !== expect_xof_bytes[15:0]) begin
        $display("FAIL %s: instrumentointi poikkeaa (hyv=%0d/%0d, hyl=%0d/%0d, xof=%0d/%0d)",
                  name, accepted_count, expect_accepted, rejected_count, expect_rejected,
                  xof_bytes_consumed, expect_xof_bytes);
        error_count++;
      end else begin
        $display("OK %s: koko SampleNTT (XOF+hylkaysnaytteenotto) tasmaa golden-malliin taydellisesti", name);
      end

      case_count++;
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
    end
    $fclose(fh);

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: koko SampleNTT (%0d testitapausta, mukaan lukien 3 C2SP-ankkuroitua unlucky-tapausta) tasmaa golden-malliin", case_count);
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
