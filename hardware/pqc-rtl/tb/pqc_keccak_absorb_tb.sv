// pqc_keccak_absorb_tb.sv
// M3 Issue #11 Vaihe B: absorbointiohjaimen testipenkki. Vertaa tilaa
// JOKAISEN lohkon jalkeen golden-malliin (ei vain lopputulosta).

`timescale 1ns/1ps

module pqc_keccak_absorb_tb;

  localparam int RATE_BYTES = 136;
  localparam int MAX_BLOCKS = 2;

  logic clk, reset, start, done;
  logic [8*RATE_BYTES*MAX_BLOCKS-1:0] padded_msg;
  logic [7:0] num_blocks;
  logic [1599:0] state_out;

  pqc_keccak_absorb #(.RATE_BYTES(RATE_BYTES), .MAX_BLOCKS(MAX_BLOCKS)) dut (
    .clk(clk), .reset(reset), .start(start),
    .padded_msg(padded_msg), .num_blocks(num_blocks),
    .state_out(state_out), .done(done)
  );

  always #5 clk = ~clk;

  logic [1599:0] block_expect [0:1];  // max 2 lohkoa per testitapaus
  int fh, scan_ok, error_count, case_count;
  string name;
  int nb;

  initial begin
    error_count = 0; case_count = 0;
    clk = 0; reset = 1; start = 0; padded_msg = '0; num_blocks = 0;

    fh = $fopen("vectors/keccak_absorb_vectors.txt", "r");

    for (int tc = 0; tc < 2; tc++) begin
      scan_ok = $fscanf(fh, "%s %d\n", name, nb);
      num_blocks = nb[7:0];
      scan_ok = $fscanf(fh, "%h\n", padded_msg);
      for (int b = 0; b < nb; b++) begin
        scan_ok = $fscanf(fh, "%h\n", block_expect[b]);
      end

      repeat (3) @(posedge clk);
      reset = 0;
      @(posedge clk);
      start <= 1'b1;
      @(posedge clk);
      start <= 1'b0;

      // Seuraa DUT:n omaa block_idx:aa ja tarkista acc_state JOKAISEN
      // lohkon (S_PERMUTE -> f1600_done) jalkeen.
      for (int b = 0; b < nb; b++) begin
        logic [1599:0] cur;
        int c;
        c = 0;
        while (!(dut.fsm_state == 2'd2 && dut.f1600_done) && c < 5000) begin
          @(posedge clk); c++;
        end
        @(posedge clk); // S_PERMUTE:n oma always_ff paivittaa acc_state:n tallaa edella
        #1; // varmista etta nonblocking-paivitys on ehtinyt asettua (Issue #10:n oppi)
        cur = dut.acc_state;
        if (cur !== block_expect[b]) begin
          $display("FAIL %s lohko %0d: tila poikkeaa golden-mallista", name, b);
          error_count++;
        end else begin
          $display("OK %s lohko %0d: tila tasmaa golden-malliin", name, b);
        end
      end

      while (!done) @(posedge clk);
      #1;
      if (state_out !== block_expect[nb-1]) begin
        $display("FAIL %s: lopputulos poikkeaa!", name);
        error_count++;
      end else begin
        $display("OK %s: lopputulos tasmaa", name);
      end

      case_count++;
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
    end
    $fclose(fh);

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: absorbointi (%0d testitapausta) tasmaa golden-malliin lohkokohtaisesti", case_count);
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
