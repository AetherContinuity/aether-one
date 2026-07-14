// pqc_ntt_inverse_12x_isolated_tb.sv
//
// M3 Issue #15 (juurisyyn jaljitys): kayttajan oma koe - aja
// run_inverse_ntt() TASMALLEEN 12 kertaa peraikkain SAMALLA acc-
// syotteella (sama arvo joka epaonnistui roundtrip-testissa 12.
// NTT-operaationa), TAYSIN ERISTETYSSA testipenkissa (ei muuta
// NTT-kutsua, ei Keccak/sample-moduuleita valissa). Jos poikkeama
// toistuu tassakin vasta 12. ajolla -> NTT-moduulin oma sisainen
// tila. Jos KAIKKI 12 ajoa antavat oikean tuloksen -> integraatio-
// testin oma ohjaus (esim. done-pulssin kasittely, reset-ajoitus
// suhteessa muihin moduuleihin).

`timescale 1ns/1ps

module pqc_ntt_inverse_12x_isolated_tb;

  localparam int COEFF_W = 16;
  localparam int SPAD_AW = 9;

  logic clk, reset, start, stage_done, bank_conflict_detected;
  logic [7:0] count, pair_dist;
  logic mode;
  logic [SPAD_AW-1:0] base_addr_lane0, base_addr_lane1;
  logic [COEFF_W-1:0] zeta_lane0, zeta_lane1;

  always #5 clk = ~clk;

  pqc_ntt_stage_banked #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW)) ntt_dut (
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

  task automatic run_inverse_ntt(input logic [256*COEFF_W-1:0] poly_in,
                                   output logic [256*COEFF_W-1:0] poly_out);
    int fh2, length, base0, zeta0, base1, zeta1, scan_ok2;
    begin
      for (int i = 0; i < 256; i++) write_bank(bank_rom_tb[i], local_rom_tb[i], poly_in[i*COEFF_W +: COEFF_W]);
      mode <= 1'b1;
      fh2 = $fopen("vectors/ntt_inverse_schedule.txt", "r");
      scan_ok2 = 5;
      while (!$feof(fh2) && scan_ok2 == 5) begin
        scan_ok2 = $fscanf(fh2, "%d %d %d %d %d\n", length, base0, zeta0, base1, zeta1);
        if (scan_ok2 == 5) run_one_level(length, base0, zeta0, base1, zeta1, length);
      end
      $fclose(fh2);
      fh2 = $fopen("vectors/ntt_inverse_level6_zeta.txt", "r");
      scan_ok2 = $fscanf(fh2, "%d\n", zeta0);
      $fclose(fh2);
      run_one_level(128, 0, zeta0, 64, zeta0, 64);
      for (int i = 0; i < 256; i++) poly_out[i*COEFF_W +: COEFF_W] = read_bank_tb(bank_rom_tb[i], local_rom_tb[i]);
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
    end
  endtask

  logic [256*COEFF_W-1:0] acc_in, inner_expect;
  logic [256*COEFF_W-1:0] result;
  int fh, scan_ok, error_count;

  initial begin
    error_count = 0;
    clk = 0; reset = 1; start = 0; count = 0; pair_dist = 0; mode = 0;
    base_addr_lane0 = 0; base_addr_lane1 = 0; zeta_lane0 = 0; zeta_lane1 = 0;

    $readmemh("m2-golden/bank_rom_4banks.memh", bank_rom_tb);
    $readmemh("m2-golden/bank_local_4banks.memh", local_rom_tb);

    fh = $fopen("vectors/isolated_ntt_inv_test.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", acc_in);
    scan_ok = $fscanf(fh, "%h\n", inner_expect);
    $fclose(fh);

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);

    for (int trial = 1; trial <= 12; trial++) begin
      run_inverse_ntt(acc_in, result);
      if (result !== inner_expect) begin
        $display("FAIL ajo %0d/12: tulos poikkeaa golden-mallista (result[0:5]=%0d,%0d,%0d,%0d,%0d)",
                  trial, result[15:0], result[31:16], result[47:32], result[63:48], result[79:64]);
        error_count++;
      end else begin
        $display("OK ajo %0d/12: tulos tasmaa golden-malliin", trial);
      end
    end

    $display("--------------------------------------------------");
    if (error_count == 0) begin
      $display("PASS: KAIKKI 12 ajoa antoivat oikean tuloksen - NTT-moduuli EI ole ongelma, tarkista integraatiotestin oma ohjaus");
    end else begin
      $display("FAIL: %0d/12 ajoa epaonnistui - NTT-moduulin oma sisainen tila epailtava", error_count);
    end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
