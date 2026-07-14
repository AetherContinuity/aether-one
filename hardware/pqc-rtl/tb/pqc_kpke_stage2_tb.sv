// pqc_kpke_stage2_tb.sv
//
// M3 Issue #8, Vaihe 2: NTT-polku ennen inverse-NTT:ta.
// u_prime[0], u_prime[1] (Vaihe 1:sta, mutta luetaan tassa suoraan
// golden-mallin omista arvoista - Vaihe 1 jo todennettu erikseen) ->
// NTT (M2:n pqc_ntt_stage_banked, aikataulupohjainen, sama schedule
// kuin 2c-ii/3c - schedule on data-riippumaton) -> MultiplyNTTs
// s_hat:n kanssa -> polyadd yli k=2:n -> sum_hat, verrattuna golden-
// malliin.

`timescale 1ns/1ps

module pqc_kpke_stage2_tb;

  localparam int COEFF_W = 16;
  localparam int SPAD_AW = 9;

  // --- NTT-ajuri (sama kuin pqc_ntt_full_banked_tb.sv, 2c-ii/3c) ---
  logic clk, reset, start, stage_done, bank_conflict_detected;
  logic [7:0] count, pair_dist;
  logic [SPAD_AW-1:0] base_addr_lane0, base_addr_lane1;
  logic [COEFF_W-1:0] zeta_lane0, zeta_lane1;

  always #5 clk = ~clk;

  pqc_ntt_stage_banked #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW)) ntt_dut (
    .clk(clk), .reset(reset), .start(start), .count(count),
    .pair_dist(pair_dist), .mode(1'b0),
    .base_addr_lane0(base_addr_lane0), .base_addr_lane1(base_addr_lane1),
    .zeta_lane0(zeta_lane0), .zeta_lane1(zeta_lane1),
    .stage_done(stage_done), .bank_conflict_detected(bank_conflict_detected),
    .load_valid(1'b0), .load_addr(8'd0), .load_data(16'd0), .read_en(1'b0), .read_addr(8'd0), .read_valid(), .read_data()
  );

  logic [1:0] bank_rom_tb  [0:255];
  logic [5:0] local_rom_tb [0:255];

  function automatic void write_bank(input [1:0] b, input [5:0] l, input [COEFF_W-1:0] val);
    case (b)
      2'd0: ntt_dut.bank0[l] = val;
      2'd1: ntt_dut.bank1[l] = val;
      2'd2: ntt_dut.bank2[l] = val;
      default: ntt_dut.bank3[l] = val;
    endcase
  endfunction

  function automatic [COEFF_W-1:0] read_bank_tb(input [1:0] b, input [5:0] l);
    case (b)
      2'd0: read_bank_tb = ntt_dut.bank0[l];
      2'd1: read_bank_tb = ntt_dut.bank1[l];
      2'd2: read_bank_tb = ntt_dut.bank2[l];
      default: read_bank_tb = ntt_dut.bank3[l];
    endcase
  endfunction

  task automatic run_ntt_schedule();
    int fh2, length, base0, zeta0, base1, zeta1, scan_ok2;
    int c;
    begin
      fh2 = $fopen("vectors/full_level6_zeta.txt", "r");
      scan_ok2 = $fscanf(fh2, "%d\n", zeta0);
      $fclose(fh2);
      pair_dist       <= 8'd128;
      base_addr_lane0 <= 9'd0;
      base_addr_lane1 <= 9'd64;
      zeta_lane0      <= zeta0[15:0];
      zeta_lane1      <= zeta0[15:0];
      count           <= 8'd64;
      @(posedge clk);
      start <= 1'b1;
      @(posedge clk);
      start <= 1'b0;
      c = 0;
      while (!stage_done && c < 3000) begin @(posedge clk); c++; end

      fh2 = $fopen("vectors/full_schedule.txt", "r");
      scan_ok2 = 5;
      while (!$feof(fh2) && scan_ok2 == 5) begin
        scan_ok2 = $fscanf(fh2, "%d %d %d %d %d\n", length, base0, zeta0, base1, zeta1);
        if (scan_ok2 == 5) begin
          pair_dist       <= 8'(length);
          base_addr_lane0 <= 9'(base0);
          base_addr_lane1 <= 9'(base1);
          zeta_lane0      <= zeta0[15:0];
          zeta_lane1      <= zeta1[15:0];
          count           <= 8'(length);
          @(posedge clk);
          start <= 1'b1;
          @(posedge clk);
          start <= 1'b0;
          c = 0;
          while (!stage_done && c < 3000) begin @(posedge clk); c++; end
        end
      end
      $fclose(fh2);
    end
  endtask

  // --- MultiplyNTTs + polyadd ---
  logic [256*COEFF_W-1:0] s_hat_0, s_hat_1;
  logic [256*COEFF_W-1:0] u_hat_0, u_hat_1;
  logic [256*COEFF_W-1:0] partial_0, partial_1;
  logic [256*COEFF_W-1:0] sum_hat, sum_hat_expect;

  pqc_multiplyntts #(.COEFF_W(COEFF_W)) mntt0 (.f_hat(s_hat_0), .g_hat(u_hat_0), .h_hat(partial_0));
  pqc_multiplyntts #(.COEFF_W(COEFF_W)) mntt1 (.f_hat(s_hat_1), .g_hat(u_hat_1), .h_hat(partial_1));
  pqc_polyadd #(.COEFF_W(COEFF_W)) padd (.a_in(partial_0), .b_in(partial_1), .sum_out(sum_hat));

  logic [256*COEFF_W-1:0] u_prime_0, u_prime_1;
  int error_count, fh, scan_ok;

  initial begin
    error_count = 0;
    clk = 0; reset = 1; start = 0; count = 0; pair_dist = 0;
    base_addr_lane0 = 0; base_addr_lane1 = 0; zeta_lane0 = 0; zeta_lane1 = 0;

    $readmemh("m2-golden/bank_rom_4banks.memh", bank_rom_tb);
    $readmemh("m2-golden/bank_local_4banks.memh", local_rom_tb);

    fh = $fopen("vectors/kpke_stage2_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", s_hat_0);
    scan_ok = $fscanf(fh, "%h\n", s_hat_1);
    scan_ok = $fscanf(fh, "%h\n", u_prime_0);
    scan_ok = $fscanf(fh, "%h\n", u_prime_1);
    scan_ok = $fscanf(fh, "%h\n", sum_hat_expect);
    $fclose(fh);

    repeat (3) @(posedge clk);
    reset = 0;
    repeat (2) @(posedge clk);

    // --- NTT(u_prime[0]) ---
    for (int i = 0; i < 256; i++) begin
      write_bank(bank_rom_tb[i], local_rom_tb[i], u_prime_0[i*COEFF_W +: COEFF_W]);
    end
    run_ntt_schedule();
    for (int i = 0; i < 256; i++) begin
      u_hat_0[i*COEFF_W +: COEFF_W] = read_bank_tb(bank_rom_tb[i], local_rom_tb[i]);
    end

    // --- NTT(u_prime[1]) - uudelleenkaytetaan sama DUT, uusi ajo ---
    reset = 1;
    @(posedge clk);
    reset = 0;
    @(posedge clk);
    for (int i = 0; i < 256; i++) begin
      write_bank(bank_rom_tb[i], local_rom_tb[i], u_prime_1[i*COEFF_W +: COEFF_W]);
    end
    run_ntt_schedule();
    for (int i = 0; i < 256; i++) begin
      u_hat_1[i*COEFF_W +: COEFF_W] = read_bank_tb(bank_rom_tb[i], local_rom_tb[i]);
    end

    #1;

    if (sum_hat !== sum_hat_expect) begin
      $display("FAIL sum_hat: %h, odotettu %h", sum_hat, sum_hat_expect);
      error_count++;
    end else $display("OK: sum_hat tasmaa golden-malliin (NTT + MultiplyNTTs + polyadd, k=2)");

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: Vaihe 2 (NTT-polku ennen inverse-NTT:ta) tasmaa golden-malliin");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
