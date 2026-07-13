// pqc_keccak_f1600_tb.sv
//
// M3 Issue #10: testipenkki Keccak-p[1600,24]-permutaatioytimelle.
// Vertaa JOKAISEN 24 kierroksen tilaa jaadytettyyn referenssiin
// (vectors/keccak_round_snapshots.json, muunnettu hex-muotoon) - EI
// vain lopputulosta. Sama periaate kuin NTT^-1:n oma tasokohtainen
// debug-tyokalu.

`timescale 1ns/1ps

module pqc_keccak_f1600_tb;

  logic clk, reset, start, done;
  logic [1599:0] state_in, state_out;

  pqc_keccak_f1600 dut (
    .clk(clk), .reset(reset), .start(start),
    .state_in(state_in), .state_out(state_out), .done(done)
  );

  always #5 clk = ~clk;

  logic [1599:0] expect_states [0:74];  // 3 testitapausta x 25 (initial+24 kierrosta)
  int fh, scan_ok;
  int error_count, case_count;
  string test_names [0:2];

  initial begin
    test_names[0] = "all_zero";
    test_names[1] = "sha3_256_abc_block";
    test_names[2] = "all_ff";

    error_count = 0;
    case_count = 0;
    clk = 0; reset = 1; start = 0; state_in = '0;

    fh = $fopen("vectors/keccak_f1600_test_vectors.txt", "r");
    for (int i = 0; i < 75; i++) begin
      scan_ok = $fscanf(fh, "%h\n", expect_states[i]);
    end
    $fclose(fh);

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);

    for (int tc = 0; tc < 3; tc++) begin
      int base_idx;
      int round_errors;
      base_idx = tc * 25;
      round_errors = 0;

      $display("=== Testitapaus: %s ===", test_names[tc]);

      state_in = expect_states[base_idx];  // initial_state
      @(posedge clk);
      start <= 1'b1;
      @(posedge clk);
      start <= 1'b0;

      // Odota S_LOAD-tila ohi, sitten tarkista jokainen 24 kierroksesta
      // hierarkkisesti DUT:n omasta A-taulukosta VALITTOMASTI kunkin
      // S_ROUND-syklin jalkeen.
      for (int r = 0; r < 24; r++) begin
        logic [1599:0] cur;
        @(posedge clk);  // yksi S_ROUND-sykli suoritettu
        #1; // varmista etta always_ff:n nonblocking-paivitys on ehtinyt asettua
        for (int i = 0; i < 25; i++) begin
          cur[i*64 +: 64] = dut.A[i%5][i/5];
        end
        if (cur !== expect_states[base_idx + 1 + r]) begin
          $display("FAIL %s kierros %0d: tila poikkeaa golden-mallista", test_names[tc], r);
          round_errors++;
          error_count++;
        end
      end

      if (round_errors == 0) begin
        $display("OK %s: kaikki 24 kierroksen valitilat tasmaavat", test_names[tc]);
      end

      // Odota done, tarkista lopputulos viela erikseen (toiminnallinen taso)
      while (!done) @(posedge clk);
      if (state_out !== expect_states[base_idx + 24]) begin
        $display("FAIL %s: lopputulos (state_out) poikkeaa!", test_names[tc]);
        error_count++;
      end else begin
        $display("OK %s: lopputulos (state_out) tasmaa", test_names[tc]);
      end

      case_count++;
      @(posedge clk);
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
    end

    $display("--------------------------------------------------");
    if (error_count == 0) begin
      $display("PASS: kaikki %0d testitapausta, kaikki 24 kierrosta + lopputulos tasmaavat jaadytettyyn referenssiin", case_count);
    end else begin
      $display("FAIL: %0d virhetta", error_count);
      $fatal(1);
    end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
