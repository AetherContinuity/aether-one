// M4-FPGA-003A: kolmivaiheinen debug-testi (kayttajan oma ehdotus)
// v10:n kirjoitus- ja lukuarbitroinnille, TAYSIN ILMAN lane_fsm:aa -
// vain bring-up-portin kautta (load_valid/read_en), jotta ongelma
// eristyy tasmalleen kirjoitus- vai lukuarbitrointiin vai ajoitukseen.
//
// Vaihe 1: kirjoita kaikki 256 osoitetta.
// Vaihe 2: lue kaikki 256 osoitetta HIERARKKISESTI (ohittaen
//          lukuarbitroinnin kokonaan) - testaa vain kirjoituspolku.
// Vaihe 3: lue samat 256 osoitetta ARBITROINNIN KAUTTA (read_en) -
//          testaa lukuarbitrointi.

`timescale 1ns/1ps

module repro_v10_debug3phase_tb;

  logic clk, reset, start;
  logic [8:0] base_addr0, base_addr1;
  logic [7:0] stride, count, pair_dist;
  logic mode;
  logic [15:0] zeta0, zeta1;
  logic done0, done1, bank_conflict_detected;
  logic load_valid;
  logic [7:0] load_addr;
  logic [15:0] load_data;
  logic read_en;
  logic [7:0] read_addr;
  logic read_valid;
  logic [15:0] read_data;

  always #5 clk = ~clk;

  repro_v10 dut (
    .clk(clk), .reset(reset), .start(start),
    .base_addr0(base_addr0), .base_addr1(base_addr1),
    .stride(stride), .count(count), .pair_dist(pair_dist), .mode(mode),
    .zeta0(zeta0), .zeta1(zeta1),
    .done0(done0), .done1(done1), .bank_conflict_detected(bank_conflict_detected),
    .load_valid(load_valid), .load_addr(load_addr), .load_data(load_data),
    .read_en(read_en), .read_addr(read_addr), .read_valid(read_valid), .read_data(read_data)
  );

  logic [15:0] expect_mem [0:255];
  int error_count;

  initial begin
    error_count = 0;
    clk = 0; reset = 1; start = 0;
    base_addr0 = 0; base_addr1 = 0; stride = 1; count = 0; pair_dist = 0; mode = 0;
    zeta0 = 0; zeta1 = 0;
    load_valid = 0; load_addr = 0; load_data = 0;
    read_en = 0; read_addr = 0;

    for (int i = 0; i < 256; i++) expect_mem[i] = i * 7 + 3;  // mielivaltainen tunnistettava kuvio

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);

    // --- VAIHE 1: kirjoita kaikki 256 osoitetta bring-up:n kautta ---
    for (int i = 0; i < 256; i++) begin
      load_valid <= 1'b1;
      load_addr  <= i[7:0];
      load_data  <= expect_mem[i];
      @(posedge clk);
    end
    load_valid <= 1'b0;
    @(posedge clk);
    $display("VAIHE 1 valmis: kaikki 256 osoitetta kirjoitettu");

    // --- VAIHE 2: lue kaikki 256 osoitetta HIERARKKISESTI (ohita
    // lukuarbitrointi kokonaan) - testaa VAIN kirjoituspolku ---
    begin
      int fail2;
      logic [1:0] b; logic [5:0] l; logic [15:0] got;
      fail2 = 0;
      for (int i = 0; i < 256; i++) begin
        b = i[1:0]^((i>>2)&2'd3)^((i>>4)&2'd3)^((i>>6)&2'd3);
        l = i[7:2];
        case (b)
          2'd0: got = dut.bank0[l];
          2'd1: got = dut.bank1[l];
          2'd2: got = dut.bank2[l];
          default: got = dut.bank3[l];
        endcase
        if (got !== expect_mem[i]) begin
          if (fail2 < 5) $display("VAIHE 2 FAIL: osoite %0d (pankki %0d, local %0d) = %0d, odotettu %0d", i, b, l, got, expect_mem[i]);
          fail2++;
        end
      end
      $display("VAIHE 2: %0d/256 virhetta (suora hierarkkinen luku, EI arbitrointia)", fail2);
      if (fail2 > 0) begin
        $display("  -> JOHTOPAATOS: KIRJOITUSPOLKU on virheellinen (muistiorganisaatio vaara)");
        error_count += fail2;
      end else begin
        $display("  -> Kirjoituspolku OK - jatketaan vaiheeseen 3");
      end
    end

    // --- VAIHE 3: lue samat 256 osoitetta ARBITROINNIN KAUTTA
    // (read_en=1, bring-up:n oma polku) ---
    begin
      int fail3;
      fail3 = 0;
      for (int i = 0; i < 256; i++) begin
        read_en   <= 1'b1;
        read_addr <= i[7:0];
        @(posedge clk);
        read_en <= 1'b0;
        @(posedge clk);  // read_valid + read_data valmis (1 syklin viive)
        if (read_data !== expect_mem[i]) begin
          if (fail3 < 10) $display("VAIHE 3 FAIL: osoite %0d = %0d, odotettu %0d", i, read_data, expect_mem[i]);
          fail3++;
        end
      end
      $display("VAIHE 3: %0d/256 virhetta (arbitroitu luku bring-up:n kautta)", fail3);
      if (fail3 > 0) begin
        $display("  -> JOHTOPAATOS: LUKUARBITROINTILOGIIKKA on virheellinen");
        error_count += fail3;
      end else begin
        $display("  -> Lukuarbitrointi OK");
      end
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: kaikki kolme vaihetta onnistuivat - kirjoitus- JA lukuarbitrointi toimivat oikein bring-up:n kautta");
    else $display("FAIL: %0d virhetta yhteensa - ks. ylla mika vaihe epaonnistui", error_count);
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
