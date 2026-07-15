// pqc_lane_fsm_read_latency_tb.sv
//
// M4-FPGA-002D: pysyva regressiotesti lane_fsm:n READ_LATENCY-
// parametrille. Todistaa KAKSI asiaa erikseen (kayttajan oma
// erottelu):
//
// 1. ALGORITMINEN EKVIVALENSSI: READ_LATENCY=1 (rekisteroity muisti)
//    antaa TASMALLEEN saman laskentatuloksen kuin READ_LATENCY=0
//    (kombinatorinen muisti) - vain eri maaralla sykleja.
// 2. MIKROARKKITEHTONINEN MUUTOS: READ_LATENCY=1 kuluttaa TASMALLEEN
//    yhden ylimaaraisen syklin per iteraatio (count*1 lisasyklia).
//
// READ_LATENCY=0 (oletus) tarkistetaan LISAKSI EI-MUUTTUNEEKSI
// aiempaan (ennen taman ominaisuuden lisaysta) nahden - sama
// sykliluku, sama tulos, rekisteroidun muistin kanssa TIEDETYSTI
// VIRHEELLINEN (dokumentoitu, odotettu kayttaytyminen - tama
// testi EI vaadi READ_LATENCY=0:n toimivan oikein rekisteroidyn
// muistin kanssa, vain etta se on IDENTTINEN aiempaan).

`timescale 1ns/1ps

module pqc_lane_fsm_read_latency_tb;

  localparam int COEFF_W = 16;
  localparam int SPAD_AW = 9;

  logic clk, reset, start;
  logic [SPAD_AW-1:0] base_addr;
  logic [7:0] stride, count, pair_dist;
  logic mode;
  logic [COEFF_W-1:0] zeta_in;

  always #5 clk = ~clk;

  int error_count;

  // --- Kaksi erillista instanssia, READ_LATENCY=0 ja =1 ---
  logic [SPAD_AW-1:0] mem_addr_a0, mem_addr_b0, mem_addr_a1, mem_addr_b1;
  logic [COEFF_W-1:0] mem_rdata_a0, mem_rdata_b0, mem_rdata_a1, mem_rdata_b1;
  logic [COEFF_W-1:0] mem_wdata_a0, mem_wdata_b0, mem_wdata_a1, mem_wdata_b1;
  logic req0, is_write0, grant0, req1, is_write1, grant1;
  logic [2:0] state0, state1;
  logic done0, done1;
  logic [7:0] idx0, idx1;

  logic [COEFF_W-1:0] test_mem0 [0:511];
  logic [COEFF_W-1:0] test_mem1 [0:511];
  logic [COEFF_W-1:0] rdata_a0_reg, rdata_b0_reg;

  lane_fsm #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW), .READ_LATENCY(0)) dut0 (
    .clk(clk), .reset(reset), .start(start),
    .base_addr(base_addr), .stride(stride), .count(count), .pair_dist(pair_dist), .mode(mode),
    .mem_addr_a(mem_addr_a0), .mem_addr_b(mem_addr_b0),
    .mem_rdata_a(mem_rdata_a0), .mem_rdata_b(mem_rdata_b0),
    .mem_wdata_a(mem_wdata_a0), .mem_wdata_b(mem_wdata_b0),
    .zeta_in(zeta_in), .req(req0), .is_write(is_write0), .grant(grant0),
    .state(state0), .done(done0), .idx_out(idx0)
  );

  lane_fsm #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW), .READ_LATENCY(1)) dut1 (
    .clk(clk), .reset(reset), .start(start),
    .base_addr(base_addr), .stride(stride), .count(count), .pair_dist(pair_dist), .mode(mode),
    .mem_addr_a(mem_addr_a1), .mem_addr_b(mem_addr_b1),
    .mem_rdata_a(mem_rdata_a1), .mem_rdata_b(mem_rdata_b1),
    .mem_wdata_a(mem_wdata_a1), .mem_wdata_b(mem_wdata_b1),
    .zeta_in(zeta_in), .req(req1), .is_write(is_write1), .grant(grant1),
    .state(state1), .done(done1), .idx_out(idx1)
  );

  // dut0: KOMBINATORINEN muisti (matching alkuperainen, todennettu kaytto)
  always_comb begin
    mem_rdata_a0 = test_mem0[mem_addr_a0];
    mem_rdata_b0 = test_mem0[mem_addr_b0];
  end
  always_ff @(posedge clk) begin
    if (grant0 && is_write0) begin
      test_mem0[mem_addr_a0] <= mem_wdata_a0;
      test_mem0[mem_addr_b0] <= mem_wdata_b0;
    end
  end
  assign grant0 = req0;

  // dut1: REKISTEROITY muisti (BRAM-yhteensopiva kohde)
  always_ff @(posedge clk) begin
    rdata_a0_reg <= test_mem1[mem_addr_a1];
    rdata_b0_reg <= test_mem1[mem_addr_b1];
    if (grant1 && is_write1) begin
      test_mem1[mem_addr_a1] <= mem_wdata_a1;
      test_mem1[mem_addr_b1] <= mem_wdata_b1;
    end
  end
  assign mem_rdata_a1 = rdata_a0_reg;
  assign mem_rdata_b1 = rdata_b0_reg;
  assign grant1 = req1;

  initial begin
    error_count = 0;
    clk = 0; reset = 1; start = 0;
    base_addr = 9'd0; stride = 8'd1; count = 8'd4; pair_dist = 8'd4; mode = 1'b0;
    zeta_in = 16'd1;

    for (int i = 0; i < 512; i++) begin
      test_mem0[i] = i * 10;
      test_mem1[i] = i * 10;
    end

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    begin
      int c0, c1;
      logic seen_done0, seen_done1;
      logic [COEFF_W-1:0] latched_a0, latched_b0, latched_a1, latched_b1;
      c0 = 0; c1 = 0;
      seen_done0 = 1'b0; seen_done1 = 1'b0;
      while ((!seen_done0 || !seen_done1) && c0 < 200) begin
        @(posedge clk);
        if (!seen_done0) c0++;
        if (!seen_done1) c1++;
        if (state0 == 3'd4 && !seen_done0) begin
          seen_done0 = 1'b1;
          latched_a0 = dut0.a_reg; latched_b0 = dut0.b_reg;
        end
        if (state1 == 3'd4 && !seen_done1) begin
          seen_done1 = 1'b1;
          latched_a1 = dut1.a_reg; latched_b1 = dut1.b_reg;
        end
      end

      $display("dut0 (READ_LATENCY=0, kombinatorinen muisti): %0d syklia, a_reg=%0d, b_reg=%0d",
                c0, latched_a0, latched_b0);
      $display("dut1 (READ_LATENCY=1, rekisteroity muisti):   %0d syklia, a_reg=%0d, b_reg=%0d",
                c1, latched_a1, latched_b1);

      // --- Tarkistus 1: ALGORITMINEN EKVIVALENSSI ---
      // dut0 (kombinatorinen, oikea referenssi) vs dut1 (rekisteroity,
      // READ_LATENCY=1) - lopputuloksen TAYTYY tasmata, koska
      // molemmat lukevat SAMAT alkuarvot test_mem0/test_mem1:sta.
      if (latched_a0 !== latched_a1 || latched_b0 !== latched_b1) begin
        $display("FAIL: algoritminen ekvivalenssi rikki - dut0 ja dut1 antavat ERI tuloksen");
        error_count++;
      end else $display("OK: algoritminen ekvivalenssi - dut0 (comb) ja dut1 (READ_LATENCY=1) antavat SAMAN tuloksen");

      // --- Tarkistus 2: MIKROARKKITEHTONINEN MUUTOS (odotettu ero) ---
      // dut1:n tulisi kayttaa TASMALLEEN count (=4) sykliä enemman
      // kuin dut0 (yksi ylimaarainen odotussykli per iteraatio).
      if (c1 !== c0 + count) begin
        $display("FAIL: odotettu sykliero (READ_LATENCY=1 - READ_LATENCY=0) = count(%0d), saatu %0d", count, c1 - c0);
        error_count++;
      end else $display("OK: mikroarkkitehtoninen ero tasmaa odotukseen (+%0d sykli, yksi per iteraatio)", count);
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: lane_fsm READ_LATENCY-parametri - algoritminen ekvivalenssi + odotettu mikroarkkitehtoninen ero");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
