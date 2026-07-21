// M3-MLKEM-002: Decaps vs. NIST ACVP (usea tapaus), Phase A / Phase B
// -syklit ERIKSEEN jokaiselle tapaukselle. Verrataan etukateen
// kirjattuun ennusteeseen (M3-MLKEM-002-encaps-decaps-plan.md):
// EI syklitasoeroa valid- ja rejection-tapausten valilla.

`timescale 1ns/1ps

module decaps_nist_multi_tb;

  localparam int K = 2;

  logic clk, reset, start, done;
  logic [8*768-1:0] c_in;
  logic [8*1632-1:0] dk_in;
  logic [255:0] K_final_out;
  logic match_out;

  always #5 clk = ~clk;

  pqc_mlkem_decaps_top #(.K(K)) dut (
    .clk(clk), .reset(reset), .start(start),
    .c_in(c_in), .dk_in(dk_in),
    .done(done), .K_final_out(K_final_out), .match_out(match_out)
  );

  int fh, scan_ok, num_vectors;
  int tc_id, rejection_expect;
  logic [8*1632-1:0] dk_val;
  logic [8*768-1:0] c_val;
  logic [255:0] k_expect;

  int phaseA_start_cycle, phaseA_end_cycle, phaseB_end_cycle;
  int cyc;

  initial begin
    clk = 0; reset = 1; start = 0;
    fh = $fopen("fpga/tau/decaps_top_nist_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%d\n", num_vectors);

    for (int i = 0; i < num_vectors; i++) begin
      scan_ok = $fscanf(fh, "%d %d\n", tc_id, rejection_expect);
      scan_ok = $fscanf(fh, "%h\n", dk_val);
      scan_ok = $fscanf(fh, "%h\n", c_val);
      scan_ok = $fscanf(fh, "%h\n", k_expect);

      dk_in = dk_val; c_in = c_val;

      repeat (3) @(posedge clk);
      reset = 0;
      cyc = 0;
      @(posedge clk); start <= 1'b1;
      @(posedge clk); start <= 1'b0;

      phaseA_end_cycle = -1;
      phaseB_end_cycle = -1;
      while (!done) begin
        @(posedge clk);
        cyc++;
        if (phaseA_end_cycle == -1 && dut.phaseA_done) phaseA_end_cycle = cyc;
        if (phaseB_end_cycle == -1 && dut.phaseB_done) phaseB_end_cycle = cyc;
      end

      $display("tcId=%0d luokka=%s(odotettu) K_tasmaa=%b match_out=%b PhaseA_paattyy_syklilla=%0d PhaseB_paattyy_syklilla=%0d PhaseB_oma_kesto=%0d kokonaissyklit=%0d",
                tc_id, rejection_expect ? "rejection" : "valid",
                (K_final_out === k_expect), match_out,
                phaseA_end_cycle, phaseB_end_cycle,
                phaseB_end_cycle - phaseA_end_cycle, cyc);

      if (K_final_out !== k_expect) begin
        $display("FAIL: tcId=%0d K EI tasmaa NIST-vektoriin", tc_id);
        $fatal(1);
      end

      @(posedge clk);
      reset = 1;
      @(posedge clk);
    end

    $fclose(fh);
    $display("--------------------------------------------------");
    $display("PASS: kaikki %0d Decaps-tapausta tasmaavat NIST-vektoreihin", num_vectors);
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
