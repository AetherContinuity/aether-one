// M4-DECAPS-ORCH-001 Phase B1 -testi: verrataan A[0][0], y_vec[0],
// e1_vec[0], e2_poly golden-referenssiin.

`timescale 1ns/1ps

module pqc_mlkem_decaps_b1_core_tb;

  localparam int COEFF_W = 16;
  localparam int K = 2;

  logic clk, reset, start, done;
  logic [8*800-1:0] ek_in;
  logic [255:0] r_prime_in;
  logic [4*256*COEFF_W-1:0] A_out_flat;
  logic [K*256*COEFF_W-1:0] y_vec_out_flat;
  logic [K*256*COEFF_W-1:0] e1_vec_out_flat;
  logic [256*COEFF_W-1:0] e2_poly_out;

  always #5 clk = ~clk;

  pqc_mlkem_decaps_b1_core #(.COEFF_W(COEFF_W), .K(K)) dut (
    .clk(clk), .reset(reset), .start(start),
    .ek_in(ek_in), .r_prime_in(r_prime_in),
    .done(done), .A_out_flat(A_out_flat),
    .y_vec_out_flat(y_vec_out_flat), .e1_vec_out_flat(e1_vec_out_flat),
    .e2_poly_out(e2_poly_out)
  );

  int fh, scan_ok, error_count;
  logic [8*800-1:0] ek;
  logic [255:0] z_seed;
  string tag;
  logic [8*768-1:0] m_prime_dummy;
  logic [256*COEFF_W-1:0] A00_golden, y0_golden, e10_golden, e2_golden;

  initial begin
    error_count = 0;
    clk = 0; reset = 1; start = 0;

    fh = $fopen("vectors/mlkem_decaps_b_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", ek);
    scan_ok = $fscanf(fh, "%h\n", z_seed);
    scan_ok = $fscanf(fh, "%s\n", tag);
    scan_ok = $fscanf(fh, "%h\n", m_prime_dummy);
    scan_ok = $fscanf(fh, "%h\n", r_prime_in);
    $fclose(fh);
    ek_in = ek;

    fh = $fopen("fpga/tau/decaps_b1_golden.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", A00_golden);
    scan_ok = $fscanf(fh, "%h\n", y0_golden);
    scan_ok = $fscanf(fh, "%h\n", e10_golden);
    scan_ok = $fscanf(fh, "%h\n", e2_golden);
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
      while (!done && wait_cycles < 10000) begin
        @(posedge clk);
        wait_cycles++;
      end
      if (!done) begin
        $display("FAIL: aikakatkaisu (%0d syklia)", wait_cycles);
        error_count++;
      end else $display("Valmis %0d syklin jalkeen", wait_cycles);
    end

    if (A_out_flat[256*COEFF_W-1:0] === A00_golden) $display("OK: A[0][0] tasmaa taydellisesti");
    else begin $display("FAIL: A[0][0] EI tasmaa"); error_count++; end

    if (y_vec_out_flat[256*COEFF_W-1:0] === y0_golden) $display("OK: y_vec[0] tasmaa taydellisesti");
    else begin $display("FAIL: y_vec[0] EI tasmaa"); error_count++; end

    if (e1_vec_out_flat[256*COEFF_W-1:0] === e10_golden) $display("OK: e1_vec[0] tasmaa taydellisesti");
    else begin $display("FAIL: e1_vec[0] EI tasmaa"); error_count++; end

    if (e2_poly_out === e2_golden) $display("OK: e2_poly tasmaa taydellisesti");
    else begin $display("FAIL: e2_poly EI tasmaa"); error_count++; end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: Decaps Phase B1 (A-matriisi + PRF/CBD-kohina) tasmaa golden-malliin");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
