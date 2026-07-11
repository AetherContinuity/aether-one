// pqc_ntt_full_banked_tb.sv
//
// M2 Vaihe 3c: KOKO 7-tasoinen Kyber-NTT, oikealla 4-pankkisella
// muistilla KAIKILLA tasoilla (myos taso 6, samalla yleisella
// pqc_ntt_stage_banked-moduulilla - ei erillista level6-erikoismoduulia
// kuten 2c-ii:ssa/3b:ssa). YKSI moduuli-instanssi koko ajolle - bank0..3
// sailyvat instanssin sisalla kaikkien 7 tason yli, ei tarvitse siirtaa
// dataa kahden eri DUT:in valilla kuten 2c-ii teki.
//
// Sama aikataulutiedosto (vectors/full_schedule.txt +
// vectors/full_level6_zeta.txt) kuin 2c-ii - ei erillista, kasin
// johdettua uutta aikataulua.

`timescale 1ns/1ps

module pqc_ntt_full_banked_tb;

  localparam int COEFF_W = 16;
  localparam int SPAD_AW = 9;

  logic clk, reset, start, stage_done, bank_conflict_detected;
  logic [7:0] count, pair_dist;
  logic [SPAD_AW-1:0] base_addr_lane0, base_addr_lane1;
  logic [COEFF_W-1:0] zeta_lane0, zeta_lane1;

  int error_count;
  int total_conflict_cycles;

  always #5 clk = ~clk;

  pqc_ntt_stage_banked #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW)) dut (
    .clk(clk), .reset(reset), .start(start), .count(count),
    .pair_dist(pair_dist),
    .base_addr_lane0(base_addr_lane0), .base_addr_lane1(base_addr_lane1),
    .zeta_lane0(zeta_lane0), .zeta_lane1(zeta_lane1),
    .stage_done(stage_done), .bank_conflict_detected(bank_conflict_detected)
  );

  logic [COEFF_W-1:0] init_mem   [0:255];
  logic [COEFF_W-1:0] expect_mem [0:255];
  logic [1:0] bank_rom_tb  [0:255];
  logic [5:0] local_rom_tb [0:255];

  int fh;
  int length, base0, zeta0, base1, zeta1;
  int scan_ok;

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

  task automatic run_wait(int max_cycles);
    int c;
    begin
      c = 0;
      while (!stage_done && c < max_cycles) begin
        if (bank_conflict_detected) total_conflict_cycles++;
        @(posedge clk);
        c++;
      end
    end
  endtask

  initial begin
    error_count = 0;
    total_conflict_cycles = 0;
    clk = 0; reset = 1;
    start = 0; count = 0; pair_dist = 0;
    base_addr_lane0 = 0; base_addr_lane1 = 0;
    zeta_lane0 = 0; zeta_lane1 = 0;

    $readmemh("vectors/full_init.memh", init_mem);
    $readmemh("vectors/full_expect.memh", expect_mem);
    $readmemh("m2-golden/bank_rom_4banks.memh", bank_rom_tb);
    $readmemh("m2-golden/bank_local_4banks.memh", local_rom_tb);

    repeat (3) @(posedge clk);
    reset = 0;
    repeat (2) @(posedge clk);

    // Alustus ROM:in kautta oikeisiin pankkeihin
    for (int i = 0; i < 256; i++) begin
      write_bank(bank_rom_tb[i], local_rom_tb[i], init_mem[i]);
    end

    // --- TASO 6 (erikoistapaus: 1 ryhma, molemmat lanet SAMA zeta) ---
    fh = $fopen("vectors/full_level6_zeta.txt", "r");
    scan_ok = $fscanf(fh, "%d\n", zeta0);
    $fclose(fh);
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
    run_wait(3000);
    if (!stage_done) begin $display("FAIL: taso 6 ei valmistunut"); error_count++; end

    // --- TASOT 5..0: luetaan aikataulu tiedostosta ---
    fh = $fopen("vectors/full_schedule.txt", "r");
    scan_ok = 5;
    while (!$feof(fh) && scan_ok == 5) begin
      scan_ok = $fscanf(fh, "%d %d %d %d %d\n", length, base0, zeta0, base1, zeta1);
      if (scan_ok == 5) begin
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
        run_wait(3000);
        if (!stage_done) begin
          $display("FAIL: taso (length=%0d, base0=%0d) ei valmistunut", length, base0);
          error_count++;
        end
      end
    end
    $fclose(fh);

    if (total_conflict_cycles > 0) begin
      $display("FAIL: %0d pankkikonfliktia havaittu koko 7-tason ajon aikana", total_conflict_cycles);
      error_count++;
    end else begin
      $display("OK: EI pankkikonflikteja koko 7-tason ajon aikana (kaikki 448 nelikkoa, ks. 3a)");
    end

    for (int i = 0; i < 256; i++) begin
      logic [COEFF_W-1:0] actual;
      actual = read_bank_tb(bank_rom_tb[i], local_rom_tb[i]);
      if (actual !== expect_mem[i]) begin
        $display("FAIL: osoite %0d = %0d, odotettu %0d", i, actual, expect_mem[i]);
        error_count++;
      end
    end

    $display("--------------------------------------------------");
    if (error_count == 0) begin
      $display("PASS: koko 7-tasoinen NTT 4-pankkisella muistilla tasmaa golden-malliin, ei konflikteja");
    end else begin
      $display("FAIL: %0d virhetta", error_count);
      $fatal(1);
    end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
