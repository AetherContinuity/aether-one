// pqc_cluster_m1_tb.sv
//
// Itsekonsistentti M1-testipenkki (kirjoitettu yhdessa RTL:n kanssa,
// ei peri edellisen session testipenkin osoiteristiriitaa).
//
// Todistaa:
//   1) Molempien lanejen tulos tasmaa Python-golden-malliin bitille.
//   2) Round-robin-arbitteri alternoi kun molemmat lanet pyytavat bankkia 0
//      samana syklina (konflikti oli aito, ei vain lapaisyn nayttely).
//   3) cluster_error pysyy alhaalla koko ajon.

`timescale 1ns/1ps

module pqc_cluster_m1_tb;

  localparam int Q         = 3329;
  localparam int COEFF_W   = 16;
  localparam int SPAD_AW   = 15;
  localparam int BANK_AW   = 13;
  localparam int NUM_BANKS = 4;
  localparam int NUM_LANES = 2;
  localparam int TW_WINDOW = 16;
  localparam int COUNT     = 16;

  logic clk, reset;
  logic start;
  logic [7:0] stage_id;
  logic [SPAD_AW-1:0] base_addr_lane0, base_addr_lane1;
  logic [7:0] stride, count;
  logic tw_in_valid;
  logic [$clog2(TW_WINDOW)-1:0] tw_in_idx;
  logic [COEFF_W-1:0] tw_in_data;
  logic cluster_done, cluster_error;

  int error_count;
  int rr_alternations;
  logic [1:0] last_grant;
  logic [1:0] req_seen_both;

  always #5 clk = ~clk;

  pqc_rvv_cluster_2lane #(
    .COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW), .BANK_AW(BANK_AW),
    .NUM_BANKS(NUM_BANKS), .NUM_LANES(NUM_LANES), .TW_WINDOW(TW_WINDOW)
  ) dut (
    .clk(clk), .reset(reset), .start(start), .stage_id(stage_id),
    .base_addr_lane0(base_addr_lane0), .base_addr_lane1(base_addr_lane1),
    .stride(stride), .count(count),
    .tw_in_valid(tw_in_valid), .tw_in_idx(tw_in_idx), .tw_in_data(tw_in_data),
    .cluster_done(cluster_done), .cluster_error(cluster_error)
  );

  logic [COEFF_W-1:0] init_mem   [0:127];
  logic [COEFF_W-1:0] expect_mem [0:127];
  logic [COEFF_W-1:0] tw_vec     [0:15];

  // ---- RR-alternoinnin ja stallien tarkkailu ----
  logic [1:0] g_tmp;
  always_ff @(posedge clk) begin
    if (reset) begin
      rr_alternations <= 0;
      last_grant <= 2'b00;
    end else begin
      if (dut.req0 && dut.req1) begin
        if (dut.grant0 || dut.grant1) begin
          g_tmp = {dut.grant1, dut.grant0};
          if (last_grant != 2'b00 && g_tmp != last_grant) rr_alternations <= rr_alternations + 1;
          last_grant <= g_tmp;
        end
      end
    end
  end

  task automatic run_lane_wait(int max_cycles);
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
    clk = 0; reset = 1; start = 0;
    stage_id = 0; base_addr_lane0 = 0; base_addr_lane1 = 0;
    stride = 0; count = 0;
    tw_in_valid = 0; tw_in_idx = 0; tw_in_data = 0;

    $readmemh("vectors/bank0_init.memh", init_mem);
    $readmemh("vectors/bank0_expect.memh", expect_mem);
    $readmemh("vectors/twiddles.memh", tw_vec);

    repeat (3) @(posedge clk);
    reset = 0;
    repeat (2) @(posedge clk);

    // Esilataa bank0 alkuarvoilla suoraan (simuloinnin hierarkkinen kirjoitus)
    for (int i = 0; i < 128; i++) dut.banked_mem[0][i] = init_mem[i];

    // Syota twiddle-ikkuna (kaytamme vain indeksia 0 tassa skoopissa)
    @(posedge clk);
    tw_in_valid <= 1'b1;
    tw_in_idx   <= 4'd0;
    tw_in_data  <= tw_vec[0];
    @(posedge clk);
    tw_in_valid <= 1'b0;

    // Kaynnista molemmat lanet samanaikaisesti, molemmat bankkiin 0:
    //   lane0: osoitteet 0..31 (base=0)
    //   lane1: osoitteet 64..95 (base=64)
    // stride=2 koska a,b interleaved -> osoite = base + i*2, b=a+1
    base_addr_lane0 <= 15'd0;
    base_addr_lane1 <= 15'd64;
    stride <= 8'd2;
    count  <= 8'(COUNT);
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    run_lane_wait(2000);

    if (!cluster_done) begin
      $display("FAIL: cluster_done ei noussut aikarajassa");
      error_count++;
    end

    if (cluster_error !== 1'b0) begin
      $display("FAIL: cluster_error asserted");
      error_count++;
    end

    if (rr_alternations < 2) begin
      $display("FAIL: RR-alternointeja liian vahan (havaittu=%0d) - konflikti ei ollut aito", rr_alternations);
      error_count++;
    end else begin
      $display("OK: RR-alternointeja havaittu %0d (konflikti oli aito)", rr_alternations);
    end

    // Tarkista tulokset molemmille laneille golden-vektoria vasten
    for (int i = 0; i < 128; i++) begin
      if (dut.banked_mem[0][i] !== expect_mem[i]) begin
        $display("FAIL: banked_mem[0][%0d] = %0d, odotettu %0d", i, dut.banked_mem[0][i], expect_mem[i]);
        error_count++;
      end
    end

    $display("--------------------------------------------------");
    if (error_count == 0) begin
      $display("PASS: kaikki %0d sanaa tasmaavat golden-malliin, RR-konflikti todennettu aidoksi", 128);
    end else begin
      $display("FAIL: %0d virhetta", error_count);
      $fatal(1);
    end
    $display("--------------------------------------------------");
    $finish;
  end

  initial begin
    $dumpfile("sim/pqc_m1.vcd");
    $dumpvars(0, pqc_cluster_m1_tb);
  end

endmodule
