// pqc_ntt_inverse_problematic_acc_stage_tb.sv
//
// M3 Issue #15 (juurisyyn jaljitys, jatko): tasokohtainen vertailu
// golden-malliin JUURI SILLE acc-syotteelle joka epaonnistuu
// deterministisesti (loydetty edellisessa kierroksessa - eristetty
// 12x-koe osoitti etta virhe ilmenee jo ENSIMMAISELLA ajolla, ei
// liity tilan sailymiseen). Sama tekniikka joka ratkaisi aiemman
// NTT^-1-ongelman (ks. NTT_INVERSE_DESIGN_NOTE.md).

`timescale 1ns/1ps

module pqc_ntt_inverse_problematic_acc_stage_tb;

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
    .load_valid(1'b0), .load_addr(8'd0), .load_data(16'd0), .read_en(1'b0), .read_addr(8'd0), .read_valid(), .read_data()
  );

  logic [1:0] bank_rom_tb  [0:255];
  logic [5:0] local_rom_tb [0:255];

  function automatic void write_bank(input [1:0] b, input [5:0] l, input [COEFF_W-1:0] val);
    case (b)
      2'd0: dut.bank0[l] = val;
      2'd1: dut.bank1[l] = val;
      2'd2: dut.bank2[l] = val;
      default: dut.bank3[l] = val;
    endcase
  endfunction

  function automatic [COEFF_W-1:0] read_bank_tb(input [1:0] b, input [5:0] l);
    case (b)
      2'd0: read_bank_tb = dut.bank0[l];
      2'd1: read_bank_tb = dut.bank1[l];
      2'd2: read_bank_tb = dut.bank2[l];
      default: read_bank_tb = dut.bank3[l];
    endcase
  endfunction

  task automatic run_one_level(input int length, input int base0, input int zeta0_int,
                                 input int base1, input int zeta1_int, input int count_val);
    int c;
    begin
      pair_dist       <= 8'(length);
      base_addr_lane0 <= 9'(base0);
      base_addr_lane1 <= 9'(base1);
      zeta_lane0      <= zeta0_int[15:0];
      zeta_lane1      <= zeta1_int[15:0];
      count           <= 8'(count_val);
      @(posedge clk);
      start <= 1'b1;
      @(posedge clk);
      start <= 1'b0;
      c = 0;
      while (!stage_done && c < 3000) begin @(posedge clk); c++; end
    end
  endtask

  logic [256*COEFF_W-1:0] acc_in;
  logic [256*COEFF_W-1:0] snapshot_expect [0:6];
  int snapshot_length [0:6];
  int error_count;

  task automatic dump_and_compare(input int level_idx, input string label);
    logic [256*COEFF_W-1:0] cur;
    int mismatch_count;
    int first_mismatch;
    int got_val, exp_val;
    begin
      for (int i = 0; i < 256; i++) cur[i*COEFF_W +: COEFF_W] = read_bank_tb(bank_rom_tb[i], local_rom_tb[i]);
      mismatch_count = 0;
      first_mismatch = -1;
      for (int i = 0; i < 256; i++) begin
        if (cur[i*COEFF_W +: COEFF_W] !== snapshot_expect[level_idx][i*COEFF_W +: COEFF_W]) begin
          mismatch_count++;
          if (first_mismatch == -1) first_mismatch = i;
        end
      end
      if (mismatch_count == 0) begin
        $display("| %0d (len=%0d) | - | 0 | PASS |", level_idx, snapshot_length[level_idx]);
      end else begin
        got_val = cur[first_mismatch*COEFF_W +: COEFF_W];
        exp_val = snapshot_expect[level_idx][first_mismatch*COEFF_W +: COEFF_W];
        $display("| %0d (len=%0d) | %0d | %0d | %0d -> %0d |", level_idx, snapshot_length[level_idx],
                  first_mismatch, mismatch_count, exp_val, got_val);
        error_count++;
      end
    end
  endtask

  int fh, scan_ok;

  initial begin
    error_count = 0;
    clk = 0; reset = 1; start = 0; count = 0; pair_dist = 0; mode = 1'b1;  // AINA inverse tassa testissa
    base_addr_lane0 = 0; base_addr_lane1 = 0; zeta_lane0 = 0; zeta_lane1 = 0;

    $readmemh("m2-golden/bank_rom_4banks.memh", bank_rom_tb);
    $readmemh("m2-golden/bank_local_4banks.memh", local_rom_tb);

    fh = $fopen("vectors/isolated_ntt_inv_test.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", acc_in);
    $fclose(fh);

    fh = $fopen("vectors/isolated_ntt_inv_stage_snapshots.txt", "r");
    for (int lvl = 0; lvl < 7; lvl++) begin
      int length_read;
      scan_ok = $fscanf(fh, "%d %h\n", length_read, snapshot_expect[lvl]);
      snapshot_length[lvl] = length_read;
    end
    $fclose(fh);

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);

    for (int i = 0; i < 256; i++) write_bank(bank_rom_tb[i], local_rom_tb[i], acc_in[i*COEFF_W +: COEFF_W]);

    $display("| Taso | Eka poikkeava idx | Poikkeamien maara | Esimerkki (odotettu -> saatu) |");
    $display("|------|--------------------|--------------------|--------------------------------|");
    begin
      int fh2, scan_ok2;
      int level_idx;
      int n_groups, length_hdr;
      int b0, z0, b1, z1;
      string tag;

      fh2 = $fopen("vectors/ntt_inverse_schedule_by_level.txt", "r");
      level_idx = 0;
      scan_ok2 = 1;
      while (!$feof(fh2) && scan_ok2 >= 1) begin
        scan_ok2 = $fscanf(fh2, "%s %d %d\n", tag, length_hdr, n_groups);
        if (scan_ok2 >= 1) begin
          for (int g = 0; g < n_groups; g++) begin
            scan_ok2 = $fscanf(fh2, "%d %d %d %d\n", b0, z0, b1, z1);
            if (length_hdr == 128)
              run_one_level(length_hdr, b0, z0, b1, z1, 64);
            else
              run_one_level(length_hdr, b0, z0, b1, z1, length_hdr);
          end
          dump_and_compare(level_idx, "");
          level_idx++;
        end
      end
      $fclose(fh2);
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("Kaikki 7 tasoa tasmaavat (odottamatonta - lopputulos oli aiemmin vaara)");
    else $display("Ensimmainen poikkeava taso loytyi ylla olevasta taulukosta - %0d/7 tasoa poikkesi", error_count);
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
