`timescale 1ns/1ps
module keygen_fwd_debug_tb;
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
  logic [4:0] prev_state;

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
    prev_state = debug_state;

    begin
      int wait_cycles;
      wait_cycles = 0;
      while (wait_cycles < 20000) begin
        @(posedge clk);
        wait_cycles++;
        if (debug_state !== prev_state) begin
          $display("t=%0d state %0d -> %0d  sched_idx=%0d stage_done=%0b ntt_start=%0b bank_conflict=%0b",
                    wait_cycles, prev_state, debug_state, dut.sched_idx, dut.stage_done, dut.ntt_start, dut.bank_conflict_detected);
          prev_state = debug_state;
        end
      end
    end
    $finish;
  end
endmodule
