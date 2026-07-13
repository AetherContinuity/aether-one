// pqc_samplentt_reject_tb.sv
//
// M3 Issue #15 Vaihe 2: SampleNTT:n hylkaysnaytteenotto-osuuden
// testipenkki. Vertaa SEKA lopullista 256 kertoimen taulukkoa ETTA
// instrumentointia (hyvaksytyt/hylatyt/kulutetut tavut) golden-
// malliin - kayttajan oma ohje.

`timescale 1ns/1ps

module pqc_samplentt_reject_tb;

  localparam int XOF_BYTES = 1008;

  logic clk, reset, start, done, error_exhausted;
  logic [8*XOF_BYTES-1:0] xof_data;
  logic [16*256-1:0] a_hat;
  logic [15:0] accepted_count, rejected_count, xof_bytes_consumed;

  pqc_samplentt_reject #(.XOF_BYTES(XOF_BYTES)) dut (
    .clk(clk), .reset(reset), .start(start),
    .xof_data(xof_data),
    .a_hat(a_hat), .accepted_count(accepted_count),
    .rejected_count(rejected_count), .xof_bytes_consumed(xof_bytes_consumed),
    .done(done), .error_exhausted(error_exhausted)
  );

  always #5 clk = ~clk;

  int fh, scan_ok, error_count, case_count;
  string name;
  int expect_accepted, expect_rejected, expect_xof_bytes;
  logic [16*256-1:0] a_hat_expect;

  initial begin
    error_count = 0; case_count = 0;
    clk = 0; reset = 1; start = 0; xof_data = '0;

    fh = $fopen("vectors/samplentt_reject_vectors.txt", "r");

    for (int tc = 0; tc < 5; tc++) begin
      scan_ok = $fscanf(fh, "%s %d %d %d\n", name, expect_accepted, expect_rejected, expect_xof_bytes);
      scan_ok = $fscanf(fh, "%h\n", xof_data);
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
      end else begin
        if (a_hat !== a_hat_expect) begin
          $display("FAIL %s: a_hat poikkeaa golden-mallista", name);
          error_count++;
        end
        if (accepted_count !== expect_accepted[15:0]) begin
          $display("FAIL %s: accepted_count=%0d, odotettu %0d", name, accepted_count, expect_accepted);
          error_count++;
        end
        if (rejected_count !== expect_rejected[15:0]) begin
          $display("FAIL %s: rejected_count=%0d, odotettu %0d", name, rejected_count, expect_rejected);
          error_count++;
        end
        if (xof_bytes_consumed !== expect_xof_bytes[15:0]) begin
          $display("FAIL %s: xof_bytes_consumed=%0d, odotettu %0d", name, xof_bytes_consumed, expect_xof_bytes);
          error_count++;
        end
        if (a_hat === a_hat_expect && accepted_count === expect_accepted[15:0] &&
            rejected_count === expect_rejected[15:0] && xof_bytes_consumed === expect_xof_bytes[15:0]) begin
          $display("OK %s: a_hat + instrumentointi (hyvaksytty=%0d, hylatty=%0d, xof_tavua=%0d) tasmaa golden-malliin",
                    name, accepted_count, rejected_count, xof_bytes_consumed);
        end
      end

      case_count++;
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
    end
    $fclose(fh);

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: SampleNTT-hylkaysnaytteenotto (%0d testitapausta, mukaan lukien 3 C2SP-ankkuroitua unlucky-tapausta) tasmaa golden-malliin", case_count);
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
