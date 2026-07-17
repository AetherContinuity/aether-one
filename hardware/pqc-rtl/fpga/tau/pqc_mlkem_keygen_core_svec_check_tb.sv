`timescale 1ns/1ps
module check_svec_tb;
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
    // Odota etta s_vec[0] on valmis: NTT-forward-vaiheen S_NTT_FWD_LOAD
    // alkaa heti CBD:n jalkeen, joten odotamme siihen (tila 12) asti
    begin
      int wait_cycles;
      wait_cycles = 0;
      while (debug_state !== 5'd12 && wait_cycles < 5000) begin
        @(posedge clk);
        wait_cycles++;
      end
      $display("Saavutti S_NTT_FWD_LOAD (12) %0d syklin jalkeen", wait_cycles);
    end
    for (int i = 0; i < 10; i++) begin
      $display("s_vec[0][%0d] = %0d", i, dut.s_vec[0][i*16 +: 16]);
    end
    $finish;
  end
endmodule
