`timescale 1ns/1ps
module keygen_core_partial_tb;
  localparam int COEFF_W = 16;
  localparam int SPAD_AW = 9;
  localparam int K = 2;

  logic clk, reset, start, done;
  logic [255:0] d_seed, z_seed;
  logic [8*800-1:0] ek_out;
  logic [8*1632-1:0] dk_out;
  logic [255:0] debug_rho, debug_sigma;
  logic [256*COEFF_W-1:0] debug_A00;
  logic [4:0] debug_state;

  always #5 clk = ~clk;

  pqc_mlkem_keygen_core #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW), .K(K)) dut (
    .clk(clk), .reset(reset), .start(start), .d_seed(d_seed), .z_seed(z_seed),
    .done(done), .ek_out(ek_out), .dk_out(dk_out),
    .debug_rho(debug_rho), .debug_sigma(debug_sigma), .debug_A00(debug_A00), .debug_state(debug_state)
  );

  logic [255:0] ek_expect_rho;  // rho on ek:n viimeiset 32 tavua (ks. testipenkin oma ek_got[(2*384)*8+:32*8])
  int fh, scan_ok;
  logic [8*800-1:0] ek_expect;
  logic [8*1632-1:0] dk_expect;

  initial begin
    clk = 0; reset = 1; start = 0;
    fh = $fopen("vectors/mlkem_keygen_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", d_seed);
    scan_ok = $fscanf(fh, "%h\n", z_seed);
    scan_ok = $fscanf(fh, "%h\n", ek_expect);
    scan_ok = $fscanf(fh, "%h\n", dk_expect);
    $fclose(fh);

    repeat(3) @(posedge clk);
    reset = 0;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    // Odota etta A[0][0] on laskettu (state etenee S_START_CBD:hen asti)
    // S_START_CBD = 8 (indeksi enumissa)
    begin
      int wait_cycles;
      wait_cycles = 0;
      while (debug_state < 5'd8 && wait_cycles < 2000) begin
        @(posedge clk);
        wait_cycles++;
      end
      $display("Odotettu %0d sykliä, state=%0d", wait_cycles, debug_state);
    end

    ek_expect_rho = ek_expect[(2*384)*8 +: 32*8];

    if (debug_rho !== ek_expect_rho) begin
      $display("FAIL: rho ei tasmaa. RTL=%h golden(ek:sta)=%h", debug_rho, ek_expect_rho);
    end else begin
      $display("OK: rho tasmaa golden-referenssiin (%h)", debug_rho);
    end

    $display("A[0][0] (ensimmaiset 32 bittia): %h", debug_A00[31:0]);
    $display("sigma: %h", debug_sigma);

    $finish;
  end
endmodule
