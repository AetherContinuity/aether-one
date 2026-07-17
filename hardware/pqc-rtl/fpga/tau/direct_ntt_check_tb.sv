`timescale 1ns/1ps
module direct_ntt_check_tb;
  localparam int COEFF_W = 16;
  localparam int SPAD_AW = 9;

  logic clk, reset, start, stage_done, bank_conflict_detected;
  logic [7:0] count, pair_dist;
  logic mode;
  logic [SPAD_AW-1:0] base_addr_lane0, base_addr_lane1;
  logic [COEFF_W-1:0] zeta_lane0, zeta_lane1;

  always #5 clk = ~clk;

  pqc_ntt_stage_banked #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW)) dut (
    .clk(clk), .reset(reset), .start(start), .count(count),
    .pair_dist(pair_dist), .mode(mode),
    .base_addr_lane0(base_addr_lane0), .base_addr_lane1(base_addr_lane1),
    .zeta_lane0(zeta_lane0), .zeta_lane1(zeta_lane1),
    .stage_done(stage_done), .bank_conflict_detected(bank_conflict_detected),
    .load_valid(1'b0), .load_addr(8'd0), .load_data(16'd0),
    .read_en(1'b0), .read_addr(8'd0), .read_valid(), .read_data()
  );

  logic [COEFF_W-1:0] init_mem [0:255];
  logic [1:0] bank_rom_tb  [0:255];
  logic [5:0] local_rom_tb [0:255];

  task automatic write_bank(input int addr, input logic [COEFF_W-1:0] val);
    case (bank_rom_tb[addr])
      2'd0: dut.bank0[local_rom_tb[addr]] = val;
      2'd1: dut.bank1[local_rom_tb[addr]] = val;
      2'd2: dut.bank2[local_rom_tb[addr]] = val;
      default: dut.bank3[local_rom_tb[addr]] = val;
    endcase
  endtask
  function automatic [COEFF_W-1:0] read_bank(input int addr);
    case (bank_rom_tb[addr])
      2'd0: read_bank = dut.bank0[local_rom_tb[addr]];
      2'd1: read_bank = dut.bank1[local_rom_tb[addr]];
      2'd2: read_bank = dut.bank2[local_rom_tb[addr]];
      default: read_bank = dut.bank3[local_rom_tb[addr]];
    endcase
  endfunction

  int fh, length, base0, zeta0, base1, zeta1, scan_ok;
  logic [256*COEFF_W-1:0] s_hat0_expect;
  int error_count;

  initial begin
    error_count = 0;
    clk = 0; reset = 1; start = 0; count = 0; pair_dist = 0; mode = 0;
    base_addr_lane0 = 0; base_addr_lane1 = 0; zeta_lane0 = 0; zeta_lane1 = 0;

    $readmemh("fpga/tau/s_vec0_direct_input.memh", init_mem);
    $readmemh("m2-golden/bank_rom_4banks.memh", bank_rom_tb);
    $readmemh("m2-golden/bank_local_4banks.memh", local_rom_tb);
    fh = $fopen("fpga/tau/s_hat0_direct_expect.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", s_hat0_expect);
    $fclose(fh);

    repeat (3) @(posedge clk);
    reset = 0;
    repeat (2) @(posedge clk);

    for (int i = 0; i < 256; i++) write_bank(i, init_mem[i]);

    // Taso 6
    fh = $fopen("vectors/full_level6_zeta.txt", "r");
    scan_ok = $fscanf(fh, "%d\n", zeta0);
    $fclose(fh);
    pair_dist <= 8'd128; base_addr_lane0 <= 9'd0; base_addr_lane1 <= 9'd64;
    zeta_lane0 <= zeta0[15:0]; zeta_lane1 <= zeta0[15:0]; count <= 8'd64;
    @(posedge clk); start <= 1'b1; @(posedge clk); start <= 1'b0;
    while (!stage_done) @(posedge clk);
    @(posedge clk);

    fh = $fopen("vectors/full_schedule.txt", "r");
    scan_ok = 5;
    while (!$feof(fh) && scan_ok == 5) begin
      scan_ok = $fscanf(fh, "%d %d %d %d %d\n", length, base0, zeta0, base1, zeta1);
      if (scan_ok == 5) begin
        pair_dist <= 8'(length); base_addr_lane0 <= 9'(base0); base_addr_lane1 <= 9'(base1);
        zeta_lane0 <= zeta0[15:0]; zeta_lane1 <= zeta1[15:0]; count <= 8'(length);
        @(posedge clk); start <= 1'b1; @(posedge clk); start <= 1'b0;
        while (!stage_done) @(posedge clk);
        @(posedge clk);
      end
    end
    $fclose(fh);

    begin
      int diffs;
      diffs = 0;
      for (int i = 0; i < 256; i++) begin
        if (read_bank(i) !== s_hat0_expect[i*16+:16]) diffs++;
      end
      if (diffs == 0) $display("PASS: suora (hierarkkinen) NTT-testi TASMAA taydellisesti s_hat[0]:hon");
      else begin
        $display("FAIL: %0d/256 eroa suorassa testissa", diffs);
        for (int i = 0; i < 10; i++)
          $display("  [%0d] RTL=%0d golden=%0d", i, read_bank(i), s_hat0_expect[i*16+:16]);
      end
    end
    $finish;
  end
endmodule
