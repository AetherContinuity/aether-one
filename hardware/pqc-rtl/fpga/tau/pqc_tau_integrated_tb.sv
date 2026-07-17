// M4-TAU-001 integraatio: paasta-paahan-testi. ECU kirjoittaa
// d_seed/z_seed Wishbone-vaylan kautta, laukaisee KeyGenin,
// odottaa valmista, lukee ek/dk takaisin - ja tarkistaa etta
// audit-loki sisaltaa TASMALLEEN kaksi merkintaa (KeyGen kaynnistetty
// + KeyGen valmis).

`timescale 1ns/1ps

module pqc_tau_integrated_tb;

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

  int fh, scan_ok;
  logic [255:0] d_seed, z_seed;
  logic [8*800-1:0] ek_expect;
  logic [8*1632-1:0] dk_expect;
  int error_count;

  initial begin
    error_count = 0;
    clk = 0; rst = 1; wb_adr = 0; wb_dat_i = 0; wb_we = 0; wb_stb = 0; wb_cyc = 0;

    fh = $fopen("vectors/mlkem_keygen_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", d_seed);
    scan_ok = $fscanf(fh, "%h\n", z_seed);
    scan_ok = $fscanf(fh, "%h\n", ek_expect);
    scan_ok = $fscanf(fh, "%h\n", dk_expect);
    $fclose(fh);

    repeat (3) @(posedge clk);
    rst = 0;
    @(posedge clk);

    // --- ECU: kirjoita d_seed 16 sanana Wishbone-vaylan kautta ---
    for (int w = 0; w < 16; w++) begin
      wb_write(11'h120, w[10:0]);        // KEYGEN_WORD_SEL
      wb_write(11'h121, d_seed[w*16+:16]); // KEYGEN_D_SEED_IN
    end
    // --- ECU: kirjoita z_seed 16 sanana ---
    for (int w = 0; w < 16; w++) begin
      wb_write(11'h120, w[10:0]);
      wb_write(11'h122, z_seed[w*16+:16]); // KEYGEN_Z_SEED_IN
    end
    $display("ECU: d_seed + z_seed kirjoitettu Wishbone-vaylan kautta");

    // --- ECU: laukaise KeyGen ---
    wb_write(11'h123, 16'd1); // KEYGEN_START
    $display("ECU: KEYGEN_START laukaistu");

    // --- ECU: odota valmis (poll KEYGEN_STATUS) ---
    begin
      logic [COEFF_W-1:0] status;
      int wait_cycles;
      wait_cycles = 0; status = 0;
      while (!status[1] && wait_cycles < 20000) begin  // bit[1] = done sticky
        wb_read(11'h124, status);
        wait_cycles++;
      end
      if (!status[1]) begin
        $display("FAIL: KeyGen ei valmistunut (wait_cycles=%0d)", wait_cycles);
        error_count++;
      end else $display("OK: KeyGen valmis %0d Wishbone-syklin jalkeen", wait_cycles);
    end

    // --- ECU: lue ek takaisin (400 sanaa), vertaa golden-referenssiin ---
    begin
      logic [8*800-1:0] ek_readback;
      logic [COEFF_W-1:0] word;
      int diffs;
      diffs = 0;
      for (int w = 0; w < 400; w++) begin
        wb_write(11'h120, w[10:0]);
        wb_read(11'h125, word);
        ek_readback[w*16+:16] = word;
      end
      if (ek_readback === ek_expect) $display("PASS: ek tasmaa taydellisesti Wishbone-vaylan kautta luettuna");
      else begin
        for (int i = 0; i < 800; i++) if (ek_readback[i*8+:8] !== ek_expect[i*8+:8]) diffs++;
        $display("FAIL: ek EI tasmaa - %0d/800 tavua eroaa", diffs);
        error_count++;
      end
    end

    // --- ECU: lue dk takaisin (816 sanaa), vertaa golden-referenssiin ---
    begin
      logic [8*1632-1:0] dk_readback;
      logic [COEFF_W-1:0] word;
      int diffs;
      diffs = 0;
      for (int w = 0; w < 816; w++) begin
        wb_write(11'h120, w[10:0]);
        wb_read(11'h126, word);
        dk_readback[w*16+:16] = word;
      end
      if (dk_readback === dk_expect) $display("PASS: dk tasmaa taydellisesti Wishbone-vaylan kautta luettuna");
      else begin
        for (int i = 0; i < 1632; i++) if (dk_readback[i*8+:8] !== dk_expect[i*8+:8]) diffs++;
        $display("FAIL: dk EI tasmaa - %0d/1632 tavua eroaa", diffs);
        error_count++;
      end
    end

    // --- Tarkista audit-loki: tasmalleen kaksi merkintaa ---
    begin
      logic [COEFF_W-1:0] log_count_word;
      wb_read(11'h114, log_count_word);  // AUDIT_SEQ (viimeisin jarjestysnumero)
      if (log_count_word !== 16'd1) begin  // seq=1 tarkoittaa 2 merkintaa (0,1)
        $display("FAIL: audit-lokin viimeisin seq=%0d, odotettu 1 (kaksi merkintaa: kaynnistys+valmistuminen)", log_count_word);
        error_count++;
      end else $display("OK: audit-loki sisaltaa tasan kaksi merkintaa (KeyGen kaynnistetty + valmis)");
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: TAU-integraatio - ECU->Wishbone->KeyGen->audit-loki->ECU koko ketju toimii");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
