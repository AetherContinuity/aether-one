// pqc_ntt_level6_tb.sv
//
// M2 Vaihe 2b -testipenkki. Todistaa: pqc_ntt_level6_2lane tuottaa
// TASMALLEEN saman tuloksen kuin Python-golden-mallin ntt_level6_only()
// koko 256-sanaiselle polynomille (ks. m2-golden/kyber_ntt_golden.py,
// itse ristiintarkistettu taydelliseen 7-tasoiseen ntt()-funktioon).

`timescale 1ns/1ps

module pqc_ntt_level6_tb;

  localparam int COEFF_W = 16;

  logic clk, reset, start, cluster_done;
  logic [7:0] count;
  logic tw_in_valid;
  logic [5:0] tw_in_idx;
  logic [COEFF_W-1:0] tw_in_data;

  int error_count;

  always #5 clk = ~clk;

  pqc_ntt_level6_2lane dut (
    .clk(clk), .reset(reset), .start(start), .count(count),
    .tw_in_valid(tw_in_valid), .tw_in_idx(tw_in_idx), .tw_in_data(tw_in_data),
    .cluster_done(cluster_done)
  );

  logic [COEFF_W-1:0] init_mem   [0:255];
  logic [COEFF_W-1:0] expect_mem [0:255];
  logic [COEFF_W-1:0] tw_vec     [0:63];

  task automatic run_wait(int max_cycles);
    int c;
    begin
      c = 0;
      while (!cluster_done && c < max_cycles) begin
        @(posedge clk);
        c++;
      end
    end
  endtask

  initial begin
    error_count = 0;
    clk = 0; reset = 1; start = 0; count = 0;
    tw_in_valid = 0; tw_in_idx = 0; tw_in_data = 0;

    $readmemh("vectors/level6_init.memh", init_mem);
    $readmemh("vectors/level6_expect.memh", expect_mem);
    $readmemh("vectors/level6_twiddles.memh", tw_vec);

    repeat (3) @(posedge clk);
    reset = 0;
    repeat (2) @(posedge clk);

    for (int i = 0; i < 256; i++) dut.mem[i] = init_mem[i];

    // Syota tw_window: sama zeta kaikkiin 64 indeksiin (taso 6:lla vain 1 zeta)
    for (int t = 0; t < 64; t++) begin
      @(posedge clk);
      tw_in_valid <= 1'b1;
      tw_in_idx   <= 6'(t);
      tw_in_data  <= tw_vec[t];
    end
    @(posedge clk);
    tw_in_valid <= 1'b0;

    count <= 8'd64;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    run_wait(3000);

    if (!cluster_done) begin
      $display("FAIL: cluster_done ei noussut aikarajassa");
      error_count++;
    end

    for (int i = 0; i < 256; i++) begin
      if (dut.mem[i] !== expect_mem[i]) begin
        $display("FAIL: mem[%0d] = %0d, odotettu %0d", i, dut.mem[i], expect_mem[i]);
        error_count++;
      end
    end

    $display("--------------------------------------------------");
    if (error_count == 0) begin
      $display("PASS: kaikki 256 sanaa tasmaavat Python-golden-malliin (ntt_level6_only)");
    end else begin
      $display("FAIL: %0d virhetta", error_count);
      $fatal(1);
    end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
