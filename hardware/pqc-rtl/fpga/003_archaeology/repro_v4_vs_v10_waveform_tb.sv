// M4-FPGA-003A: aaltomuotovertailu - v4 (VANHA, ei-arbitroitu, TIEDETAAN
// toimivaksi) vs v10 (UUSI, arbitroitu, BRAM-yhteensopiva) rinnakkain,
// sama syote, yksi lane (lane0), yksi butterfly-operaatio. Tavoite:
// loytaa ENSIMMAINEN sykli jolla signaalit eroavat.

`timescale 1ns/1ps

module repro_v4_vs_v10_waveform_tb;

  logic clk, reset, start;
  logic [8:0] base_addr0, base_addr1;
  logic [7:0] stride, count, pair_dist;
  logic mode;
  logic [15:0] zeta0, zeta1;

  // --- v4 (vanha, ei bring-up-portteja) ---
  logic v4_done0, v4_done1;
  repro_v4 dut_old (
    .clk(clk), .reset(reset), .start(start),
    .base_addr0(base_addr0), .base_addr1(base_addr1),
    .stride(stride), .count(count), .pair_dist(pair_dist), .mode(mode),
    .zeta0(zeta0), .zeta1(zeta1),
    .done0(v4_done0), .done1(v4_done1)
  );

  // --- v10 (uusi, arbitroitu, bring-up passiivinen) ---
  logic v10_done0, v10_done1, v10_conflict;
  repro_v10 dut_new (
    .clk(clk), .reset(reset), .start(start),
    .base_addr0(base_addr0), .base_addr1(base_addr1),
    .stride(stride), .count(count), .pair_dist(pair_dist), .mode(mode),
    .zeta0(zeta0), .zeta1(zeta1),
    .done0(v10_done0), .done1(v10_done1), .bank_conflict_detected(v10_conflict),
    .load_valid(1'b0), .load_addr(8'd0), .load_data(16'd0),
    .read_en(1'b0), .read_addr(8'd0), .read_valid(), .read_data()
  );

  // --- Alustus: SAMAT arvot molempiin, VAIN loogisen osoitteen
  // 0-63 alueelle (mika on itse asiassa AINOA local_of():n koskaan
  // palauttama alue - v10:n 128-koko on vain BRAM-yhteensopivuutta
  // varten, ei aidosti kaytossa yli local-indeksin 63) ---
  initial begin
    for (int i = 0; i < 64; i++) begin
      dut_old.bank0[i] = i*10;   dut_new.bank0[i] = i*10;
      dut_old.bank1[i] = i*10+1; dut_new.bank1[i] = i*10+1;
      dut_old.bank2[i] = i*10+2; dut_new.bank2[i] = i*10+2;
      dut_old.bank3[i] = i*10+3; dut_new.bank3[i] = i*10+3;
    end
  end

  always #5 clk = ~clk;

  int cycle_count;
  logic first_diff_found;

  initial begin
    clk = 0; reset = 1; start = 0;
    base_addr0 = 0; base_addr1 = 64; stride = 1; count = 4; pair_dist = 4; mode = 0;
    zeta0 = 1; zeta1 = 1;
    cycle_count = 0;
    first_diff_found = 1'b0;

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    $display("sykli | v4: s0 aa0 ab0 a0 b0 | s1 aa1 ab1 a1 b1 | v10: s0 aa0 ab0 a0 b0 | s1 aa1 ab1 a1 b1 | ERO?");
    for (cycle_count = 1; cycle_count <= 25; cycle_count++) begin
      @(posedge clk);
      begin
        logic diff;
        diff = 1'b0;
        if (dut_old.lane0.state !== dut_new.lane0.state) diff = 1'b1;
        if (dut_old.lane1.state !== dut_new.lane1.state) diff = 1'b1;
        if (dut_old.addr_a0 !== dut_new.addr_a0) diff = 1'b1;
        if (dut_old.addr_b0 !== dut_new.addr_b0) diff = 1'b1;
        if (dut_old.addr_a1 !== dut_new.addr_a1) diff = 1'b1;
        if (dut_old.addr_b1 !== dut_new.addr_b1) diff = 1'b1;
        if (dut_old.lane0.a_reg !== dut_new.lane0.a_reg) diff = 1'b1;
        if (dut_old.lane0.b_reg !== dut_new.lane0.b_reg) diff = 1'b1;
        if (dut_old.lane1.a_reg !== dut_new.lane1.a_reg) diff = 1'b1;
        if (dut_old.lane1.b_reg !== dut_new.lane1.b_reg) diff = 1'b1;

        $display("%5d | %2d %3d %3d %3d %3d | %2d %3d %3d %3d %3d | %2d %3d %3d %3d %3d | %2d %3d %3d %3d %3d | %s",
                  cycle_count,
                  dut_old.lane0.state, dut_old.addr_a0, dut_old.addr_b0, dut_old.lane0.a_reg, dut_old.lane0.b_reg,
                  dut_old.lane1.state, dut_old.addr_a1, dut_old.addr_b1, dut_old.lane1.a_reg, dut_old.lane1.b_reg,
                  dut_new.lane0.state, dut_new.addr_a0, dut_new.addr_b0, dut_new.lane0.a_reg, dut_new.lane0.b_reg,
                  dut_new.lane1.state, dut_new.addr_a1, dut_new.addr_b1, dut_new.lane1.a_reg, dut_new.lane1.b_reg,
                  diff ? "<-- ERO" : "");

        if (diff && !first_diff_found) begin
          first_diff_found = 1'b1;
          $display("--------------------------------------------------");
          $display("ENSIMMAINEN ERO loytyi syklilla %0d", cycle_count);
          $display("--------------------------------------------------");
        end
      end
    end

    if (!first_diff_found) $display("EI EROA loydetty ensimmaisen 25 syklin aikana");
    $finish;
  end

endmodule
