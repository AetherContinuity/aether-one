// M4-DECAPS-ORCH-001: koko Decaps-huippumoduulin paasta-paahan-testi.
// Verrataan K_final:ia riippumattomasti generoituun testivektoriin
// (mlkem_keygen_internal -> mlkem_encaps_internal -> mlkem_decaps_internal).

`timescale 1ns/1ps

module pqc_mlkem_decaps_top_tb;

  localparam int COEFF_W = 16;
  localparam int SPAD_AW = 9;
  localparam int K = 2;

  logic clk, reset, start, done;
  logic [8*768-1:0] c_in;
  logic [8*1632-1:0] dk_in;
  logic [255:0] K_final_out;
  logic match_out;

  always #5 clk = ~clk;

  pqc_mlkem_decaps_top #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW), .K(K)) dut (
    .clk(clk), .reset(reset), .start(start),
    .c_in(c_in), .dk_in(dk_in),
    .done(done), .K_final_out(K_final_out), .match_out(match_out)
  );

  int fh, scan_ok;
  logic [255:0] K_expect;

  initial begin
    clk = 0; reset = 1; start = 0;

    fh = $fopen("fpga/tau/decaps_top_e2e_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", dk_in);
    scan_ok = $fscanf(fh, "%h\n", c_in);
    scan_ok = $fscanf(fh, "%h\n", K_expect);
    $fclose(fh);

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    begin
      int wait_cycles;
      wait_cycles = 0;
      while (!done && wait_cycles < 40000) begin
        @(posedge clk);
        wait_cycles++;
      end
      if (!done) $display("FAIL: aikakatkaisu (%0d syklia)", wait_cycles);
      else $display("Valmis %0d syklin jalkeen", wait_cycles);
    end

    $display("match_out: %0b (odotettu: 1, koska c on aito, oikein muodostettu siffertext)", match_out);

    if (K_final_out === K_expect) begin
      $display("PASS: koko Decaps-huippumoduuli - K_final tasmaa taydellisesti riippumattomaan testivektoriin");
    end else begin
      $display("FAIL: K_final EI tasmaa");
      $display("  RTL:    %h", K_final_out);
      $display("  golden: %h", K_expect);
      $fatal(1);
    end
    $finish;
  end

endmodule
