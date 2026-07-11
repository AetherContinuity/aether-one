// pqc_ntt_chain_tb.sv
//
// M2 Vaihe 2c-i: taso6 -> taso5 -ketjun testipenkki. Sama
// pqc_ntt_stage_2lane-instanssi ajetaan KAHDESTI peräkkäin samalla
// muistilla, eri ajonaikaisilla parametreilla (pair_dist, base_addr,
// zeta) kummallakin kerralla. Todistaa: tasojen valinen siirtyma
// toimii - taso 6:n tulos on oikea SYOTE tasolle 5, ei vain etta
// kumpikin taso erikseen toimisi jos ajettaisiin tyhjasta.
//
// Tarkistaa SEKA valitilan (heti taso 6 jalkeen, ennen taso 5:ta)
// ETTA lopputilan (taso 5 jalkeen) - ei vain lopputulosta, koska
// deterministinen ketju voisi teoriassa naytta oikealta lopussa
// vaikka valivaihe olisi vaara (jos virheet kumoutuisivat, epatodennakoista
// mutta ei tarkistettu ilman erillista valitarkistusta).

`timescale 1ns/1ps

module pqc_ntt_chain_tb;

  localparam int COEFF_W = 16;
  localparam int SPAD_AW = 9;

  logic clk, reset, start, stage_done;
  logic [7:0] count, pair_dist;
  logic [SPAD_AW-1:0] base_addr_lane0, base_addr_lane1;
  logic [COEFF_W-1:0] zeta_lane0, zeta_lane1;

  int error_count;

  always #5 clk = ~clk;

  pqc_ntt_stage_2lane #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW)) dut (
    .clk(clk), .reset(reset), .start(start), .count(count),
    .pair_dist(pair_dist),
    .base_addr_lane0(base_addr_lane0), .base_addr_lane1(base_addr_lane1),
    .zeta_lane0(zeta_lane0), .zeta_lane1(zeta_lane1),
    .stage_done(stage_done)
  );

  logic [COEFF_W-1:0] init_mem     [0:255];
  logic [COEFF_W-1:0] after_l6_mem [0:255];
  logic [COEFF_W-1:0] final_mem    [0:255];
  int zeta6, zeta5_g0, zeta5_g1;
  int fh;

  task automatic run_wait(int max_cycles);
    int c;
    begin
      c = 0;
      while (!stage_done && c < max_cycles) begin
        @(posedge clk);
        c++;
      end
    end
  endtask

  initial begin
    error_count = 0;
    clk = 0; reset = 1; start = 0;
    count = 0; pair_dist = 0;
    base_addr_lane0 = 0; base_addr_lane1 = 0;
    zeta_lane0 = 0; zeta_lane1 = 0;

    $readmemh("vectors/chain_init.memh", init_mem);
    $readmemh("vectors/chain_after_l6.memh", after_l6_mem);
    $readmemh("vectors/chain_final.memh", final_mem);

    fh = $fopen("vectors/chain_zetas.txt", "r");
    void'($fscanf(fh, "%d\n", zeta6));
    void'($fscanf(fh, "%d\n", zeta5_g0));
    void'($fscanf(fh, "%d\n", zeta5_g1));
    $fclose(fh);

    repeat (3) @(posedge clk);
    reset = 0;
    repeat (2) @(posedge clk);

    for (int i = 0; i < 256; i++) dut.mem[i] = init_mem[i];

    // ---- AJO 1: taso 6 (1 ryhma, molemmat lanet sama zeta, pair_dist=128) ----
    pair_dist       <= 8'd128;
    base_addr_lane0 <= 9'd0;
    base_addr_lane1 <= 9'd64;
    zeta_lane0      <= zeta6[15:0];
    zeta_lane1      <= zeta6[15:0];
    count           <= 8'd64;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;
    run_wait(3000);

    if (!stage_done) begin
      $display("FAIL: taso 6 ei valmistunut aikarajassa");
      error_count++;
    end

    // Tarkista VALITILA ennen tason 5 ajoa
    for (int i = 0; i < 256; i++) begin
      if (dut.mem[i] !== after_l6_mem[i]) begin
        $display("FAIL (valitila taso6 jalkeen): mem[%0d]=%0d, odotettu %0d", i, dut.mem[i], after_l6_mem[i]);
        error_count++;
      end
    end
    if (error_count == 0) $display("OK: valitila taso 6 jalkeen tasmaa golden-malliin (kaikki 256 sanaa)");

    // ---- AJO 2: taso 5 (2 ryhmaa, eri zeta per lane, pair_dist=64) ----
    @(posedge clk);
    pair_dist       <= 8'd64;
    base_addr_lane0 <= 9'd0;    // ryhma 0: osoitteet 0..63 / 64..127
    base_addr_lane1 <= 9'd128; // ryhma 1: osoitteet 128..191 / 192..255
    zeta_lane0      <= zeta5_g0[15:0];
    zeta_lane1      <= zeta5_g1[15:0];
    count           <= 8'd64;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;
    run_wait(3000);

    if (!stage_done) begin
      $display("FAIL: taso 5 ei valmistunut aikarajassa");
      error_count++;
    end

    // Tarkista LOPPUTILA
    for (int i = 0; i < 256; i++) begin
      if (dut.mem[i] !== final_mem[i]) begin
        $display("FAIL (lopputila taso5 jalkeen): mem[%0d]=%0d, odotettu %0d", i, dut.mem[i], final_mem[i]);
        error_count++;
      end
    end

    $display("--------------------------------------------------");
    if (error_count == 0) begin
      $display("PASS: taso6->taso5-ketju tasmaa Python-golden-malliin seka vali- etta lopputilassa");
    end else begin
      $display("FAIL: %0d virhetta", error_count);
      $fatal(1);
    end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
