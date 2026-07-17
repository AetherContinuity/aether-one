`timescale 1ns/1ps
module check_that_tb;
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
  logic [256*COEFF_W-1:0] t_hat0_golden;
  initial begin
    clk = 0; reset = 1; start = 0;
    fh = $fopen("vectors/mlkem_keygen_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", d_seed);
    scan_ok = $fscanf(fh, "%h\n", z_seed);
    scan_ok = $fscanf(fh, "%h\n", ek_expect);
    scan_ok = $fscanf(fh, "%h\n", dk_expect);
    $fclose(fh);
    fh = $fopen("fpga/tau/t_hat0_golden.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", t_hat0_golden);
    $fclose(fh);

    repeat(3) @(posedge clk);
    reset = 0;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;
    while (!done) @(posedge clk);

    if (dut.t_hat[0] === t_hat0_golden) $display("PASS: t_hat[0] TASMAA taydellisesti");
    else begin
      int diffs;
      diffs = 0;
      for (int i = 0; i < 256; i++) if (dut.t_hat[0][i*16+:16] !== t_hat0_golden[i*16+:16]) diffs++;
      $display("FAIL: t_hat[0] - %0d/256 eroaa", diffs);
      for (int i = 0; i < 10; i++)
        $display("  [%0d] RTL=%0d golden=%0d", i, dut.t_hat[0][i*16+:16], t_hat0_golden[i*16+:16]);
    end
    $finish;
  end
endmodule
