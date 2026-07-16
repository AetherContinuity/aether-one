// M4-FPGA-003A: "golden trace" -vertailu (kayttajan oma ehdotus).
// Ajaa OIKEAN, todennetun tuotantoytimen (pqc_ntt_stage_banked) ja
// UUDEN arbitroidun v10:n RINNAKKAIN, SAMALLA todellisella
// aikataululla (vectors/full_schedule.txt + full_level6_zeta.txt),
// ja vertaa PANKKIEN TAYTTA SISALTOA (256 kerrointa) JOKAISEN
// TASON JALKEEN - loytaa ENSIMMAISEN tason jolla ne alkavat poiketa.

`timescale 1ns/1ps

module golden_trace_compare_tb;

  localparam int COEFF_W = 16;
  localparam int SPAD_AW = 9;

  logic clk, reset, start;
  logic [7:0] count, pair_dist;
  logic [SPAD_AW-1:0] base_addr_lane0, base_addr_lane1;
  logic [COEFF_W-1:0] zeta_lane0, zeta_lane1;

  // --- VANHA: oikea tuotantoydin ---
  logic old_stage_done, old_bank_conflict;
  pqc_ntt_stage_banked #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW)) dut_old (
    .clk(clk), .reset(reset), .start(start), .count(count),
    .pair_dist(pair_dist), .mode(1'b0),
    .base_addr_lane0(base_addr_lane0), .base_addr_lane1(base_addr_lane1),
    .zeta_lane0(zeta_lane0), .zeta_lane1(zeta_lane1),
    .stage_done(old_stage_done), .bank_conflict_detected(old_bank_conflict),
    .load_valid(1'b0), .load_addr(8'd0), .load_data(16'd0),
    .read_en(1'b0), .read_addr(8'd0), .read_valid(), .read_data()
  );

  // --- UUSI: v10 (arbitroitu) ---
  logic new_done0, new_done1, new_bank_conflict;
  repro_v10 dut_new (
    .clk(clk), .reset(reset), .start(start),
    .base_addr0(base_addr_lane0), .base_addr1(base_addr_lane1),
    .stride(8'd1), .count(count), .pair_dist(pair_dist), .mode(1'b0),
    .zeta0(zeta_lane0), .zeta1(zeta_lane1),
    .done0(new_done0), .done1(new_done1), .bank_conflict_detected(new_bank_conflict),
    .load_valid(1'b0), .load_addr(8'd0), .load_data(16'd0),
    .read_en(1'b0), .read_addr(8'd0), .read_valid(), .read_data()
  );
  wire new_stage_done = new_done0 && new_done1;

  always #5 clk = ~clk;

  logic [COEFF_W-1:0] init_mem [0:255];
  logic [1:0] bank_rom_tb  [0:255];
  logic [5:0] local_rom_tb [0:255];

  function automatic void write_bank_old(input [1:0] b, input [5:0] l, input [COEFF_W-1:0] val);
    case (b)
      2'd0: dut_old.bank0[l] = val; 2'd1: dut_old.bank1[l] = val;
      2'd2: dut_old.bank2[l] = val; default: dut_old.bank3[l] = val;
    endcase
  endfunction
  function automatic void write_bank_new(input [1:0] b, input [5:0] l, input [COEFF_W-1:0] val);
    case (b)
      2'd0: dut_new.bank0[l] = val; 2'd1: dut_new.bank1[l] = val;
      2'd2: dut_new.bank2[l] = val; default: dut_new.bank3[l] = val;
    endcase
  endfunction
  function automatic [COEFF_W-1:0] read_bank_old(input [1:0] b, input [5:0] l);
    case (b)
      2'd0: read_bank_old = dut_old.bank0[l]; 2'd1: read_bank_old = dut_old.bank1[l];
      2'd2: read_bank_old = dut_old.bank2[l]; default: read_bank_old = dut_old.bank3[l];
    endcase
  endfunction
  function automatic [COEFF_W-1:0] read_bank_new(input [1:0] b, input [5:0] l);
    case (b)
      2'd0: read_bank_new = dut_new.bank0[l]; 2'd1: read_bank_new = dut_new.bank1[l];
      2'd2: read_bank_new = dut_new.bank2[l]; default: read_bank_new = dut_new.bank3[l];
    endcase
  endfunction

  // v10 kayttaa SISAISESTI omaa XOR-kaavaansa, EI vanhaa SAT-ratkaistua
  // bank_rom_tb/local_rom_tb-taulukkoa - naiden pitaa tasmata v10:n
  // omaan sisaiseen kartoitukseen kirjoitusta/lukua varten!
  function automatic logic [1:0] xor_bank_of(input logic [7:0] a);
    xor_bank_of = a[1:0] ^ a[3:2] ^ a[5:4] ^ a[7:6];
  endfunction
  function automatic logic [5:0] xor_local_of(input logic [7:0] a);
    xor_local_of = a[7:2];
  endfunction

  int fh, length, base0, zeta0, base1, zeta1, scan_ok;
  int level_num;
  logic first_diff_found;

  task automatic run_wait(int max_cycles);
    int c;
    logic seen_old, seen_new;
    begin
      c = 0;
      seen_old = 1'b0; seen_new = 1'b0;
      while (!(seen_old && seen_new) && c < max_cycles) begin
        @(posedge clk);
        c++;
        if (old_stage_done) seen_old = 1'b1;
        if (new_stage_done) seen_new = 1'b1;
      end
      if (c >= max_cycles) $display("VAROITUS: run_wait aikakatkaistiin (seen_old=%0b, seen_new=%0b)", seen_old, seen_new);
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
    end
  endtask

  task automatic compare_banks(input string label);
    int diffs;
    int first_addr;
    diffs = 0; first_addr = -1;
    for (int i = 0; i < 256; i++) begin
      if (read_bank_old(bank_rom_tb[i], local_rom_tb[i]) !== read_bank_new(xor_bank_of(i[7:0]), xor_local_of(i[7:0]))) begin
        diffs++;
        if (first_addr == -1) first_addr = i;
      end
    end
    if (diffs > 0 && !first_diff_found) begin
      first_diff_found = 1'b1;
      $display("--------------------------------------------------");
      $display("ENSIMMAINEN ERO loytyi TASOLLA: %s (%0d/256 osoitetta eroaa, eka=%0d, vanha=%0d, uusi=%0d)",
                label, diffs, first_addr, read_bank_old(bank_rom_tb[first_addr], local_rom_tb[first_addr]),
                read_bank_new(xor_bank_of(first_addr[7:0]), xor_local_of(first_addr[7:0])));
      $display("--------------------------------------------------");
    end else if (diffs > 0) begin
      $display("%s: %0d/256 osoitetta eroaa (ei ensimmainen)", label, diffs);
    end else begin
      $display("%s: TASMAA (0 eroa)", label);
    end
  endtask

  initial begin
    clk = 0; reset = 1; start = 0; count = 0; pair_dist = 0;
    base_addr_lane0 = 0; base_addr_lane1 = 0; zeta_lane0 = 0; zeta_lane1 = 0;
    first_diff_found = 1'b0;
    level_num = 0;

    $readmemh("vectors/full_init.memh", init_mem);
    $readmemh("m2-golden/bank_rom_4banks.memh", bank_rom_tb);
    $readmemh("m2-golden/bank_local_4banks.memh", local_rom_tb);

    repeat (3) @(posedge clk);
    reset = 0;
    repeat (2) @(posedge clk);

    for (int i = 0; i < 256; i++) begin
      write_bank_old(bank_rom_tb[i], local_rom_tb[i], init_mem[i]);
      write_bank_new(xor_bank_of(i[7:0]), xor_local_of(i[7:0]), init_mem[i]);
    end
    compare_banks("ALKUARVOT");

    // --- TASO 6 ---
    fh = $fopen("vectors/full_level6_zeta.txt", "r");
    scan_ok = $fscanf(fh, "%d\n", zeta0);
    $fclose(fh);
    pair_dist <= 8'd128; base_addr_lane0 <= 9'd0; base_addr_lane1 <= 9'd64;
    zeta_lane0 <= zeta0[15:0]; zeta_lane1 <= zeta0[15:0]; count <= 8'd64;
    @(posedge clk); start <= 1'b1; @(posedge clk); start <= 1'b0;
    run_wait(3000);
    level_num++;
    compare_banks($sformatf("TASO 6 (level_num=%0d)", level_num));

    // --- TASOT 5..0 ---
    fh = $fopen("vectors/full_schedule.txt", "r");
    scan_ok = 5;
    while (!$feof(fh) && scan_ok == 5 && !first_diff_found) begin
      scan_ok = $fscanf(fh, "%d %d %d %d %d\n", length, base0, zeta0, base1, zeta1);
      if (scan_ok == 5) begin
        pair_dist <= 8'(length); base_addr_lane0 <= 9'(base0); base_addr_lane1 <= 9'(base1);
        zeta_lane0 <= zeta0[15:0]; zeta_lane1 <= zeta1[15:0]; count <= 8'(length);
        @(posedge clk); start <= 1'b1; @(posedge clk); start <= 1'b0;
        run_wait(3000);
        level_num++;
        compare_banks($sformatf("length=%0d base0=%0d base1=%0d (level_num=%0d)", length, base0, base1, level_num));
      end
    end
    $fclose(fh);

    $display("--------------------------------------------------");
    if (!first_diff_found) $display("EI EROA loydetty koko 7-tason ajon aikana - v4/v10 tasmaavat taydellisesti");
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
