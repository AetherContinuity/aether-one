// M4-TAU-001 / koko ML-KEM-protokollaketjun paasta-paahan-testi:
// ECU kaynnistaa KeyGenin (saa ek+dk), sitten Encapsin (kayttaen
// SAMAA ek:ta, saa K_encaps+c), sitten Decapsin (kayttaen SAMAA
// dk+c:ta, saa K_decaps) - ja tarkistaa etta K_encaps === K_decaps.
//
// TAMA ON ENSIMMAINEN TESTI JOKA VALIDOI KOKO PROTOKOLLAKETJUN
// (ei vain yksittaisia algoritmeja) YHDEN TAU-KEHYKSEN SISALLA.
// Kaikki kolme operaatiota kayttavat TAYSIN SATUNNAISIA syotteita
// (d_seed/z_seed/viesti simuloitu ECU:n omalla, ohjelmiston puolella
// generoidulla datalla) - EI mitaan aiemmin kaytettya, jaadytettya
// testivektoria.

`timescale 1ns/1ps

module pqc_tau_full_protocol_tb;

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

  logic [255:0] d_seed, z_seed, m_msg;
  logic [8*800-1:0] ek_readback;
  logic [8*1632-1:0] dk_readback;
  logic [255:0] K_encaps_readback;
  logic [8*768-1:0] c_readback;
  logic [255:0] K_decaps_readback;
  int error_count;

  initial begin
    error_count = 0;
    clk = 0; rst = 1; wb_adr = 0; wb_dat_i = 0; wb_we = 0; wb_stb = 0; wb_cyc = 0;

    // ECU:n oma, taysin satunnainen syote (EI jaadytetty testivektori)
    d_seed = {$random, $random, $random, $random, $random, $random, $random, $random};
    z_seed = {$random, $random, $random, $random, $random, $random, $random, $random};
    m_msg  = {$random, $random, $random, $random, $random, $random, $random, $random};

    repeat (3) @(posedge clk);
    rst = 0;
    @(posedge clk);

    // === Vaihe 1: KeyGen ===
    $display("=== Vaihe 1: KeyGen ===");
    for (int w = 0; w < 16; w++) begin
      wb_write(11'h120, w[10:0]);
      wb_write(11'h121, d_seed[w*16+:16]);
    end
    for (int w = 0; w < 16; w++) begin
      wb_write(11'h120, w[10:0]);
      wb_write(11'h122, z_seed[w*16+:16]);
    end
    wb_write(11'h123, 16'd1);  // KEYGEN_START

    begin
      logic [COEFF_W-1:0] status;
      int wait_cycles;
      wait_cycles = 0; status = 0;
      while (!status[1] && wait_cycles < 20000) begin
        wb_read(11'h124, status);
        wait_cycles++;
      end
      if (!status[1]) begin
        $display("FAIL: KeyGen ei valmistunut"); error_count++;
      end else $display("OK: KeyGen valmis %0d syklin jalkeen", wait_cycles);
    end

    for (int w = 0; w < 400; w++) begin
      logic [COEFF_W-1:0] word;
      wb_write(11'h120, w[10:0]);
      wb_read(11'h125, word);
      ek_readback[w*16+:16] = word;
    end
    for (int w = 0; w < 816; w++) begin
      logic [COEFF_W-1:0] word;
      wb_write(11'h120, w[10:0]);
      wb_read(11'h126, word);
      dk_readback[w*16+:16] = word;
    end
    $display("ek + dk luettu takaisin Wishbone-vaylan kautta");

    reset_and_wait();

    // === Vaihe 2: Encaps (kayttaen KeyGenin OMAA ek:ta) ===
    $display("=== Vaihe 2: Encaps ===");
    for (int w = 0; w < 400; w++) begin
      wb_write(11'h140, w[10:0]);
      wb_write(11'h141, ek_readback[w*16+:16]);
    end
    for (int w = 0; w < 16; w++) begin
      wb_write(11'h140, w[10:0]);
      wb_write(11'h142, m_msg[w*16+:16]);
    end
    wb_write(11'h143, 16'd1);  // ENCAPS_START

    begin
      logic [COEFF_W-1:0] status;
      int wait_cycles;
      wait_cycles = 0; status = 0;
      while (!status[1] && wait_cycles < 20000) begin
        wb_read(11'h144, status);
        wait_cycles++;
      end
      if (!status[1]) begin
        $display("FAIL: Encaps ei valmistunut"); error_count++;
      end else $display("OK: Encaps valmis %0d syklin jalkeen", wait_cycles);
    end

    for (int w = 0; w < 16; w++) begin
      logic [COEFF_W-1:0] word;
      wb_write(11'h140, w[10:0]);
      wb_read(11'h145, word);
      K_encaps_readback[w*16+:16] = word;
    end
    for (int w = 0; w < 384; w++) begin
      logic [COEFF_W-1:0] word;
      wb_write(11'h140, w[10:0]);
      wb_read(11'h146, word);
      c_readback[w*16+:16] = word;
    end
    $display("K_encaps + c luettu takaisin Wishbone-vaylan kautta");

    reset_and_wait();

    // === Vaihe 3: Decaps (kayttaen KeyGenin OMAA dk:ta JA Encapsin OMAA c:ta) ===
    $display("=== Vaihe 3: Decaps ===");
    for (int w = 0; w < 384; w++) begin
      wb_write(11'h130, w[10:0]);
      wb_write(11'h131, c_readback[w*16+:16]);
    end
    for (int w = 0; w < 816; w++) begin
      wb_write(11'h130, w[10:0]);
      wb_write(11'h132, dk_readback[w*16+:16]);
    end
    wb_write(11'h133, 16'd1);  // DECAPS_START

    begin
      logic [COEFF_W-1:0] status;
      int wait_cycles;
      wait_cycles = 0; status = 0;
      while (!status[1] && wait_cycles < 40000) begin
        wb_read(11'h134, status);
        wait_cycles++;
      end
      if (!status[1]) begin
        $display("FAIL: Decaps ei valmistunut"); error_count++;
      end else $display("OK: Decaps valmis %0d syklin jalkeen", wait_cycles);
    end

    begin
      logic [COEFF_W-1:0] match_word;
      wb_read(11'h136, match_word);
      if (match_word[0] !== 1'b1) begin
        $display("FAIL: Decapsin oma match=0 - ciphertext ei tunnistettu aidoksi!");
        error_count++;
      end else $display("OK: Decapsin oma match=1 (aito ciphertext)");
    end

    for (int w = 0; w < 16; w++) begin
      logic [COEFF_W-1:0] word;
      wb_write(11'h130, w[10:0]);
      wb_read(11'h135, word);
      K_decaps_readback[w*16+:16] = word;
    end
    $display("K_decaps luettu takaisin Wishbone-vaylan kautta");

    // === Lopullinen tarkistus: jaettu salaisuus tasmaa ===
    $display("=== Lopullinen tarkistus ===");
    if (K_encaps_readback === K_decaps_readback) begin
      $display("PASS: K_encaps === K_decaps - KOKO ML-KEM-PROTOKOLLAKETJU TOIMII PAASTA PAAHAN!");
    end else begin
      $display("FAIL: K_encaps != K_decaps");
      $display("  K_encaps: %h", K_encaps_readback);
      $display("  K_decaps: %h", K_decaps_readback);
      error_count++;
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: KOKO ML-KEM-PROTOKOLLA (KeyGen->Encaps->Decaps) TOIMII YHDESSA TAU-KEHYKSESSA");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

  task automatic reset_and_wait();
    begin
      rst = 1;
      repeat (3) @(posedge clk);
      rst = 0;
      @(posedge clk);
    end
  endtask

endmodule
