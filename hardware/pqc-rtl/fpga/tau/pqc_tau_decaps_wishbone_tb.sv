// M4-DECAPS-ORCH-001 Wishbone-integraatiotesti: ECU kirjoittaa dk+c
// Wishbone-vaylan kautta, laukaisee Decapsin, pollaa DECAPS_STATUS:ia,
// lukee K_final+match takaisin - verrataan tuoreeseen, riippumattomaan
// testivektoriin (sama kuin pqc_mlkem_decaps_top_tb.sv:ssa).

`timescale 1ns/1ps

module pqc_tau_decaps_wishbone_tb;

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

  int fh, scan_ok, error_count;
  logic [8*1632-1:0] dk;
  logic [8*768-1:0] c;
  logic [255:0] K_expect;

  initial begin
    error_count = 0;
    clk = 0; rst = 1; wb_adr = 0; wb_dat_i = 0; wb_we = 0; wb_stb = 0; wb_cyc = 0;

    fh = $fopen("fpga/tau/decaps_top_e2e_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", dk);
    scan_ok = $fscanf(fh, "%h\n", c);
    scan_ok = $fscanf(fh, "%h\n", K_expect);
    $fclose(fh);

    repeat (3) @(posedge clk);
    rst = 0;
    @(posedge clk);

    // --- ECU: kirjoita c (384 sanaa) ---
    for (int w = 0; w < 384; w++) begin
      wb_write(11'h130, w[10:0]);           // DECAPS_WORD_SEL
      wb_write(11'h131, c[w*16+:16]);        // DECAPS_C_IN
    end
    $display("ECU: c kirjoitettu Wishbone-vaylan kautta (384 sanaa)");

    // --- ECU: kirjoita dk (816 sanaa) ---
    for (int w = 0; w < 816; w++) begin
      wb_write(11'h130, w[10:0]);
      wb_write(11'h132, dk[w*16+:16]);       // DECAPS_DK_IN
    end
    $display("ECU: dk kirjoitettu Wishbone-vaylan kautta (816 sanaa)");

    // --- ECU: laukaise Decaps ---
    wb_write(11'h133, 16'd1);  // DECAPS_START
    $display("ECU: DECAPS_START laukaistu");

    // --- ECU: odota valmis ---
    begin
      logic [COEFF_W-1:0] status;
      int wait_cycles;
      wait_cycles = 0; status = 0;
      while (!status[1] && wait_cycles < 40000) begin
        wb_read(11'h134, status);  // DECAPS_STATUS
        wait_cycles++;
      end
      if (!status[1]) begin
        $display("FAIL: Decaps ei valmistunut (wait_cycles=%0d)", wait_cycles);
        error_count++;
      end else $display("OK: Decaps valmis %0d Wishbone-syklin jalkeen", wait_cycles);
    end

    // --- ECU: lue match ---
    begin
      logic [COEFF_W-1:0] match_word;
      wb_read(11'h136, match_word);  // DECAPS_MATCH
      $display("match: %0b (odotettu: 1, aito siffertext)", match_word[0]);
      if (match_word[0] !== 1'b1) begin
        $display("FAIL: match odotettiin 1:ksi");
        error_count++;
      end
    end

    // --- ECU: lue K_final takaisin (16 sanaa), vertaa golden-referenssiin ---
    begin
      logic [255:0] K_readback;
      logic [COEFF_W-1:0] word;
      for (int w = 0; w < 16; w++) begin
        wb_write(11'h130, w[10:0]);
        wb_read(11'h135, word);  // DECAPS_K_FINAL_OUT
        K_readback[w*16+:16] = word;
      end
      if (K_readback === K_expect) $display("PASS: K_final tasmaa taydellisesti Wishbone-vaylan kautta luettuna");
      else begin
        $display("FAIL: K_final EI tasmaa");
        $display("  RTL:    %h", K_readback);
        $display("  golden: %h", K_expect);
        error_count++;
      end
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: Decaps-Wishbone-integraatio - ECU->Wishbone->Decaps->ECU koko ketju toimii");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
