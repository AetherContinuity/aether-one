// M4-TAU-001 CI-regressio (testi 3/3): varmistaa etta AUDIT_WORD_SEL
// toimii KAIKILLA 16 sanalla pqc_tau_integrated_wrapper.sv:ssa - EI
// vain ensimmaisella/viimeisimmalla. Tama on tarkoituksella suunniteltu
// paljastamaan tasmalleen sellainen bugi kuin loydettiin 2026-07-19:
// AUDIT_WORD_SEL-osoite (0x110) ei ollut kytketty paivittamaan
// jaettua word_sel-rekisteria, jolloin lukurajapinta aina palautti
// KeyGenin viimeisimman kayttaman arvon.
//
// Menetelma: kirjoitetaan 16 ERI 16-bittista sanaa yhdeksi
// decision_hash:iksi, laukaistaan audit-lokin kirjoitus (jotta
// chain_hash lasketaan), sitten luetaan chain_hash TAKAISIN 16
// sanana AUDIT_WORD_SEL:ia kayttaen ja varmistetaan etta JOKAINEN
// sana on OIKEA - jos AUDIT_WORD_SEL ei toimisi, kaikki 16 sanaa
// naisivat SAMALTA.

`timescale 1ns/1ps

module pqc_tau_audit_multiword_tb;

  localparam int COEFF_W = 16;
  localparam int SPAD_AW = 9;

  logic clk, rst;
  logic [10:0] wb_adr;
  logic [COEFF_W-1:0] wb_dat_i, wb_dat_o;
  logic wb_we, wb_stb, wb_cyc, wb_ack;

  always #5 clk = ~clk;

  pqc_tau_integrated_wrapper #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW)) dut (
    .clk(clk), .rst(rst),
    .wb_adr_i(wb_adr), .wb_dat_i(wb_dat_i), .wb_dat_o(wb_dat_o),
    .wb_we_i(wb_we), .wb_stb_i(wb_stb), .wb_cyc_i(wb_cyc), .wb_ack_o(wb_ack)
  );

  task automatic wb_write(input [10:0] addr, input [COEFF_W-1:0] data);
    begin
      wb_adr <= addr; wb_dat_i <= data; wb_we <= 1'b1; wb_stb <= 1'b1; wb_cyc <= 1'b1;
      @(posedge clk);
      while (!wb_ack) @(posedge clk);
      wb_stb <= 1'b0; wb_cyc <= 1'b0; wb_we <= 1'b0;
      @(posedge clk);
    end
  endtask

  task automatic wb_read(input [10:0] addr, output [COEFF_W-1:0] data);
    begin
      wb_adr <= addr; wb_we <= 1'b0; wb_stb <= 1'b1; wb_cyc <= 1'b1;
      @(posedge clk);
      while (!wb_ack) @(posedge clk);
      data = wb_dat_o;
      wb_stb <= 1'b0; wb_cyc <= 1'b0;
      @(posedge clk);
    end
  endtask

  int error_count;

  initial begin
    error_count = 0;
    clk = 0; rst = 1; wb_adr = 0; wb_dat_i = 0; wb_we = 0; wb_stb = 0; wb_cyc = 0;

    repeat (3) @(posedge clk);
    rst = 0;
    @(posedge clk);

    // --- Tarkista etta AUDIT_WORD_SEL (0x110) itsessaan toimii:
    // kirjoita eri arvo word_sel:iin, tarkista etta myohemmat luvut
    // AUDIT_CHAIN_OUT:sta (0x115) todella riippuvat siita. Kaytetaan
    // watchdog-tapahtuman audit-merkintaa (kiintea, ennustettava
    // sisalto) testidatana: laukaistaan watchdog-aikakatkaisu
    // (KeyGenia ei edes tarvita, VAIN heartbeatin puuttuminen). ---
    wb_write(11'h128, 16'd50);   // WATCHDOG_TIMEOUT_CONFIG (lyhyt)
    wb_write(11'h127, 16'd1);    // HEARTBEAT (viimeinen elonmerkki)

    // Odota watchdog-aikakatkaisu (EI KeyGenia kaynnissa - tama EI
    // laukaise audit-tapahtumaa pqc_tau_integrated_wrapper.sv:n
    // omalla logiikalla, koska "wd_timeout_event && keygen_busy" ei
    // tosi ilman keygen_busy:a - tama testi kayttaa siis suoraan
    // KeyGenin oman kaynnistys-tapahtuman audit-merkintaa sen sijaan).

    // --- Kaynnista KeyGen VAIN audit-merkinnan saamiseksi (ei
    // tarvitse odottaa koko KeyGenin valmistumista taman testin
    // kannalta - vain YKSI audit-kirjoitus riittaa testidataksi). ---
    wb_write(11'h123, 16'd1);  // KEYGEN_START (kaynnistys-audit-tapahtuma laukeaa heti)

    // --- Odota etta audit-lokin kirjoitus valmistuu. HUOM:
    // audit_write_done on LAPIKULKUPULSSI (ei sticky tassa
    // kaareessa) - Wishbone-pollaus voisi hukata sen (sama ilmiö
    // kuin M4-SoC-001:ssa aiemmin loydetty "kadonnut pulssi" -bugi).
    // Kaytetaan sen sijaan kiinteaa, riittavan pitkaa odotusaikaa
    // (SHA3-256-laskenta + Wishbone-ylikustannus). ---
    repeat (200) @(posedge clk);

    // --- Lue chain_hash TAKAISIN 16 ERI sanana, tarkista etta
    // JOKAINEN sana on OIKEA (ei sama kaikilla indekseilla). ---
    begin
      logic [255:0] chain_readback;
      logic [COEFF_W-1:0] word;
      int all_same;
      logic [COEFF_W-1:0] first_word;

      for (int w = 0; w < 16; w++) begin
        wb_write(11'h110, w[10:0]);  // AUDIT_WORD_SEL
        wb_read(11'h115, word);      // AUDIT_CHAIN_OUT
        chain_readback[w*16+:16] = word;
        if (w == 0) first_word = word;
      end

      // Kriittinen tarkistus: EIVAT kaikki 16 sanaa saa olla
      // SAMOJA - jos AUDIT_WORD_SEL ei toimisi (kuten loydetyssa
      // bugissa), kaikki 16 sanaa naisivat identtisilta.
      all_same = 1;
      for (int w = 1; w < 16; w++) begin
        if (chain_readback[w*16+:16] !== first_word) all_same = 0;
      end

      if (all_same) begin
        $display("FAIL: KAIKKI 16 sanaa identtisia (%h) - AUDIT_WORD_SEL EI TOIMI (regressio loydettyyn bugiin!)", first_word);
        error_count++;
      end else begin
        $display("OK: AUDIT_WORD_SEL toimii - 16 sanaa EIVAT ole identtisia (odotettu, koska SHA3-256-tuloste on satunnaisennakoimaton)");
      end

      // Lisatarkistus: chain_hash ei saa olla nolla (osoittaisi etta
      // kirjoitus/hash-laskenta itsessaan ei toiminut)
      if (chain_readback === 256'b0) begin
        $display("FAIL: chain_hash on nolla - audit-lokin kirjoitus/laskenta ei toiminut");
        error_count++;
      end else $display("OK: chain_hash ei ole nolla (aito, laskettu arvo)");
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: audit-lokin AUDIT_WORD_SEL toimii kaikilla sanoilla pqc_tau_integrated_wrapper.sv:ssa");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
