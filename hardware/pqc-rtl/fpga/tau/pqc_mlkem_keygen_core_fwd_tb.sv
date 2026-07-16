`timescale 1ns/1ps
module keygen_core_fwd_tb;
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

    begin
      int wait_cycles;
      wait_cycles = 0;
      while (debug_state != 5'd24 && wait_cycles < 50000) begin  // S_DONE oletettu indeksi 24
        @(posedge clk);
        wait_cycles++;
        if (wait_cycles % 5000 == 0) $display("...  wait_cycles=%0d state=%0d", wait_cycles, debug_state);
      end
      $display("Paattyi %0d syklin jalkeen, state=%0d", wait_cycles, debug_state);
    end

    $display("s_hat[0] ensimmaiset 32 bittia: %h", dut.s_hat[0][31:0]);
    $display("e_hat[0] ensimmaiset 32 bittia: %h", dut.e_hat[0][31:0]);
    $finish;
  end
endmodule
