// pqc_ntt_inverse_roundtrip_tb.sv
//
// M3 Issue #8, Vaihe 3: itsenainen NTT^-1-validointi ENNEN K-PKE.Decryptin
// integraatiota (kayttajan oman jarjestyksen mukaisesti). Ajaa AIDON
// RTL:n (pqc_ntt_stage_banked, sama moduuli molempiin suuntiin, mode-
// portilla valittuna) forward-NTT:n, sitten inverse-NTT:n SAMALLE
// datalle, sitten final_scale, ja tarkistaa etta NTT^-1(NTT(f)) == f
// - taydellinen round-trip, ei vain golden-mallia vastaan (joka on jo
// todistanut taman M2 Vaihe 2a:ssa), vaan OIKEALLA RTL:lla molempiin
// suuntiin.

`timescale 1ns/1ps

module pqc_ntt_inverse_roundtrip_tb;

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
    .stage_done(stage_done), .bank_conflict_detected(bank_conflict_detected)
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
                                 input int base1, input int zeta1_int);
    int c;
    begin
      pair_dist       <= 8'(length);
      base_addr_lane0 <= 9'(base0);
      base_addr_lane1 <= 9'(base1);
      zeta_lane0      <= zeta0_int[15:0];
      zeta_lane1      <= zeta1_int[15:0];
      count           <= 8'(length);
      @(posedge clk);
      start <= 1'b1;
      @(posedge clk);
      start <= 1'b0;
      c = 0;
      while (!stage_done && c < 3000) begin @(posedge clk); c++; end
    end
  endtask

  task automatic run_forward_ntt();
    int fh2, zeta0, length, base0, base1, zeta1, scan_ok2;
    begin
      mode <= 1'b0;
      fh2 = $fopen("vectors/full_level6_zeta.txt", "r");
      scan_ok2 = $fscanf(fh2, "%d\n", zeta0);
      $fclose(fh2);
      run_one_level(128, 0, zeta0, 64, zeta0);

      fh2 = $fopen("vectors/full_schedule.txt", "r");
      scan_ok2 = 5;
      while (!$feof(fh2) && scan_ok2 == 5) begin
        scan_ok2 = $fscanf(fh2, "%d %d %d %d %d\n", length, base0, zeta0, base1, zeta1);
        if (scan_ok2 == 5) run_one_level(length, base0, zeta0, base1, zeta1);
      end
      $fclose(fh2);
    end
  endtask

  task automatic run_inverse_ntt();
    int fh2, zeta0, length, base0, base1, zeta1, scan_ok2;
    begin
      mode <= 1'b1;
      fh2 = $fopen("vectors/ntt_inverse_schedule.txt", "r");
      scan_ok2 = 5;
      while (!$feof(fh2) && scan_ok2 == 5) begin
        scan_ok2 = $fscanf(fh2, "%d %d %d %d %d\n", length, base0, zeta0, base1, zeta1);
        if (scan_ok2 == 5) run_one_level(length, base0, zeta0, base1, zeta1);
      end
      $fclose(fh2);

      fh2 = $fopen("vectors/ntt_inverse_level6_zeta.txt", "r");
      scan_ok2 = $fscanf(fh2, "%d\n", zeta0);
      $fclose(fh2);
      run_one_level(128, 0, zeta0, 64, zeta0);
    end
  endtask

  logic [256*COEFF_W-1:0] f_orig, f_hat_rtl, f_recovered_raw, f_recovered_scaled;
  pqc_ntt_final_scale #(.COEFF_W(COEFF_W)) scale_dut (.f_in(f_recovered_raw), .f_out(f_recovered_scaled));

  int error_count;
  int Q;

  initial begin
    error_count = 0;
    Q = 3329;
    clk = 0; reset = 1; start = 0; count = 0; pair_dist = 0; mode = 0;
    base_addr_lane0 = 0; base_addr_lane1 = 0; zeta_lane0 = 0; zeta_lane1 = 0;

    $readmemh("m2-golden/bank_rom_4banks.memh", bank_rom_tb);
    $readmemh("m2-golden/bank_local_4banks.memh", local_rom_tb);

    // Satunnainen testidata suoraan Verilogissa (yksinkertainen LCG, ei
    // tarvitse golden-mallia tahan - round-trip on itsessaan todiste,
    // riippumatta f:n arvoista)
    begin
      int seed;
      seed = 12345;
      for (int i = 0; i < 256; i++) begin
        seed = (seed * 1103515245 + 12345) & 32'h7FFFFFFF;
        f_orig[i*COEFF_W +: COEFF_W] = (seed % Q);
      end
    end

    repeat (3) @(posedge clk);
    reset = 0;
    repeat (2) @(posedge clk);

    for (int i = 0; i < 256; i++) write_bank(bank_rom_tb[i], local_rom_tb[i], f_orig[i*COEFF_W +: COEFF_W]);
    run_forward_ntt();
    for (int i = 0; i < 256; i++) f_hat_rtl[i*COEFF_W +: COEFF_W] = read_bank_tb(bank_rom_tb[i], local_rom_tb[i]);

    $display("Eteenpain-NTT valmis, ajetaan kaanteinen samalle datalle...");

    reset = 1;
    @(posedge clk);
    reset = 0;
    @(posedge clk);

    for (int i = 0; i < 256; i++) write_bank(bank_rom_tb[i], local_rom_tb[i], f_hat_rtl[i*COEFF_W +: COEFF_W]);
    run_inverse_ntt();
    for (int i = 0; i < 256; i++) f_recovered_raw[i*COEFF_W +: COEFF_W] = read_bank_tb(bank_rom_tb[i], local_rom_tb[i]);

    #1;

    if (f_recovered_scaled !== f_orig) begin
      $display("FAIL: NTT^-1(NTT(f)) != f");
      for (int i = 0; i < 256; i++) begin
        if (f_recovered_scaled[i*COEFF_W +: COEFF_W] !== f_orig[i*COEFF_W +: COEFF_W]) begin
          $display("  ero kohdassa %0d: %0d != %0d", i,
                    f_recovered_scaled[i*COEFF_W +: COEFF_W], f_orig[i*COEFF_W +: COEFF_W]);
        end
      end
      error_count++;
    end else begin
      $display("OK: NTT^-1(NTT(f)) == f - taydellinen round-trip AIDOLLA RTL:lla molempiin suuntiin");
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: NTT^-1 round-trip -testi lapaisty");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
