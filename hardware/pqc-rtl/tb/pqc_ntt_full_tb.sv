// pqc_ntt_full_tb.sv
//
// M2 Vaihe 2c-ii: KOKO 7-tasoinen Kyber-NTT. Taso 6 ajetaan olemassa
// olevalla, jo todennetulla pqc_ntt_level6_2lane-moduulilla (ei muuteta).
// Tasot 5..0 ajetaan pqc_ntt_stage_2lane-moduulilla TOISTUVASTI, lukien
// aikataulun (length, base0, zeta0, base1, zeta1) suoraan tiedostosta
// jonka Python-golden-malli generoi TASMALLEEN samasta silmukka-
// rakenteesta kuin jo riippumattomasti todennettu ntt()-funktio - ei
// erillista, kasin johdettua osoite/zeta-logiikkaa tassa testipenkissa.

`timescale 1ns/1ps

module pqc_ntt_full_tb;

  localparam int COEFF_W = 16;
  localparam int SPAD_AW = 9;

  logic clk, reset;

  // --- Taso 6 (pqc_ntt_level6_2lane) ---
  logic l6_start, l6_done;
  logic [7:0] l6_count;
  logic l6_tw_valid;
  logic [5:0] l6_tw_idx;
  logic [COEFF_W-1:0] l6_tw_data;

  pqc_ntt_level6_2lane #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW)) dut_l6 (
    .clk(clk), .reset(reset), .start(l6_start), .count(l6_count),
    .tw_in_valid(l6_tw_valid), .tw_in_idx(l6_tw_idx), .tw_in_data(l6_tw_data),
    .cluster_done(l6_done)
  );

  // --- Tasot 5..0 (pqc_ntt_stage_2lane) ---
  logic stg_start, stg_done;
  logic [7:0] stg_count, stg_pair_dist;
  logic [SPAD_AW-1:0] stg_base0, stg_base1;
  logic [COEFF_W-1:0] stg_zeta0, stg_zeta1;

  pqc_ntt_stage_2lane #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW)) dut_stg (
    .clk(clk), .reset(reset), .start(stg_start), .count(stg_count),
    .pair_dist(stg_pair_dist),
    .base_addr_lane0(stg_base0), .base_addr_lane1(stg_base1),
    .zeta_lane0(stg_zeta0), .zeta_lane1(stg_zeta1),
    .stage_done(stg_done)
  );

  always #5 clk = ~clk;

  logic [COEFF_W-1:0] init_mem   [0:255];
  logic [COEFF_W-1:0] expect_mem [0:255];
  logic [COEFF_W-1:0] shared_mem [0:255];  // "muisti" jaettuna molempien DUTien valilla, ohjattu testipenkin toimesta

  int error_count;
  int fh;
  int length, base0, zeta0, base1, zeta1;
  int scan_ok;

  task automatic run_wait_l6(int max_cycles);
    int c;
    begin
      c = 0;
      while (!l6_done && c < max_cycles) begin @(posedge clk); c++; end
    end
  endtask

  task automatic run_wait_stg(int max_cycles);
    int c;
    begin
      c = 0;
      while (!stg_done && c < max_cycles) begin @(posedge clk); c++; end
    end
  endtask

  initial begin
    error_count = 0;
    clk = 0; reset = 1;
    l6_start = 0; l6_count = 0; l6_tw_valid = 0; l6_tw_idx = 0; l6_tw_data = 0;
    stg_start = 0; stg_count = 0; stg_pair_dist = 0;
    stg_base0 = 0; stg_base1 = 0; stg_zeta0 = 0; stg_zeta1 = 0;

    $readmemh("vectors/full_init.memh", init_mem);
    $readmemh("vectors/full_expect.memh", expect_mem);

    repeat (3) @(posedge clk);
    reset = 0;
    repeat (2) @(posedge clk);

    // --- Alustus: kirjoita init_mem SEKA dut_l6:n etta dut_stg:n omaan
    // muistiin (kumpikin moduuli pitaa oman [0:255]-taulukkonsa - taso 6
    // kayttaa dut_l6:n muistia, seuraavat askeleet siirtavat tuloksen
    // dut_stg:n muistiin ennen tasojen 5..0 ajoa) ---
    for (int i = 0; i < 256; i++) dut_l6.mem[i] = init_mem[i];

    // --- TASO 6 (dut_l6) ---
    fh = $fopen("vectors/full_level6_zeta.txt", "r");
    scan_ok = $fscanf(fh, "%d\n", zeta0);
    $fclose(fh);
    for (int t = 0; t < 64; t++) begin
      @(posedge clk);
      l6_tw_valid <= 1'b1;
      l6_tw_idx   <= 6'(t);
      l6_tw_data  <= zeta0[15:0];
    end
    @(posedge clk);
    l6_tw_valid <= 1'b0;
    l6_count <= 8'd64;
    @(posedge clk);
    l6_start <= 1'b1;
    @(posedge clk);
    l6_start <= 1'b0;
    run_wait_l6(3000);
    if (!l6_done) begin $display("FAIL: taso 6 ei valmistunut"); error_count++; end

    // Siirra taso 6:n tulos dut_stg:n omaan muistiin jatkoa varten
    for (int i = 0; i < 256; i++) dut_stg.mem[i] = dut_l6.mem[i];

    // --- TASOT 5..0: luetaan aikataulu tiedostosta, ajetaan rivi kerrallaan ---
    fh = $fopen("vectors/full_schedule.txt", "r");
    scan_ok = 5;
    while (!$feof(fh) && scan_ok == 5) begin
      scan_ok = $fscanf(fh, "%d %d %d %d %d\n", length, base0, zeta0, base1, zeta1);
      if (scan_ok == 5) begin
      stg_pair_dist <= 8'(length);
      stg_base0     <= 9'(base0);
      stg_base1     <= 9'(base1);
      stg_zeta0     <= zeta0[15:0];
      stg_zeta1     <= zeta1[15:0];
      stg_count     <= 8'(length);
      @(posedge clk);
      stg_start <= 1'b1;
      @(posedge clk);
      stg_start <= 1'b0;
      run_wait_stg(3000);
      if (!stg_done) begin
        $display("FAIL: taso (length=%0d, base0=%0d) ei valmistunut", length, base0);
        error_count++;
      end
      end
    end
    $fclose(fh);

    // --- Tarkista lopputulos ---
    for (int i = 0; i < 256; i++) begin
      if (dut_stg.mem[i] !== expect_mem[i]) begin
        $display("FAIL: mem[%0d] = %0d, odotettu %0d", i, dut_stg.mem[i], expect_mem[i]);
        error_count++;
      end
    end

    $display("--------------------------------------------------");
    if (error_count == 0) begin
      $display("PASS: koko 7-tasoinen NTT tasmaa Python-golden-malliin (ntt()), kaikki 256 sanaa");
    end else begin
      $display("FAIL: %0d virhetta", error_count);
      $fatal(1);
    end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
