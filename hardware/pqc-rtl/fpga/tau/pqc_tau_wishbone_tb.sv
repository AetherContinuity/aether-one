// M4-TAU-001: TAU-Wishbone-kaareen integraatiotesti. Kirjoittaa
// decision_hash:in 16 sanana Wishbone-vaylan kautta, laukaisee
// audit-lokin kirjoituksen, ja lukee chain_hash:in takaisin -
// vertaa samaan Python-golden-referenssiin kuin M4-TAU-001 Osa 1.

`timescale 1ns/1ps

module pqc_tau_wishbone_tb;

  localparam int COEFF_W = 16;
  localparam int SPAD_AW = 9;

  logic clk, rst;
  logic [9:0] wb_adr;
  logic [COEFF_W-1:0] wb_dat_i, wb_dat_o;
  logic wb_we, wb_stb, wb_cyc, wb_ack;

  always #5 clk = ~clk;

  pqc_tau_wishbone_wrapper #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW)) dut (
    .clk(clk), .rst(rst),
    .wb_adr_i(wb_adr), .wb_dat_i(wb_dat_i), .wb_dat_o(wb_dat_o),
    .wb_we_i(wb_we), .wb_stb_i(wb_stb), .wb_cyc_i(wb_cyc), .wb_ack_o(wb_ack)
  );

  task automatic wb_write(input [9:0] addr, input [COEFF_W-1:0] data);
    begin
      wb_adr <= addr; wb_dat_i <= data; wb_we <= 1'b1; wb_stb <= 1'b1; wb_cyc <= 1'b1;
      @(posedge clk);
      while (!wb_ack) @(posedge clk);
      wb_stb <= 1'b0; wb_cyc <= 1'b0; wb_we <= 1'b0;
      @(posedge clk);
    end
  endtask

  task automatic wb_read(input [9:0] addr, output [COEFF_W-1:0] data);
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
  logic [255:0] golden_decision_hash, golden_chain_hash;
  int error_count;

  initial begin
    error_count = 0;
    clk = 0; rst = 1; wb_adr = 0; wb_dat_i = 0; wb_we = 0; wb_stb = 0; wb_cyc = 0;

    // Lue ENSIMMAINEN Python-golden-referenssin merkinta (seq=0,
    // genesis chain_head=0 - sama kuin M4-TAU-001 Osa 1:ssa)
    fh = $fopen("fpga/tau/audit_log_golden.txt", "r");
    begin
      int seq_dummy;
      scan_ok = $fscanf(fh, "%d %h %h\n", seq_dummy, golden_decision_hash, golden_chain_hash);
    end
    $fclose(fh);

    repeat (3) @(posedge clk);
    rst = 0;
    @(posedge clk);

    // --- Kirjoita decision_hash 16 sanana Wishbone-vaylan kautta ---
    for (int w = 0; w < 16; w++) begin
      wb_write(10'h110, w[9:0]);  // AUDIT_WORD_SEL
      wb_write(10'h111, golden_decision_hash[w*16 +: 16]);  // AUDIT_HASH_IN
    end
    $display("decision_hash kirjoitettu 16 sanana Wishbone-vaylan kautta");

    // --- Laukaise audit-lokin kirjoitus ---
    wb_write(10'h112, 16'd1);  // AUDIT_COMMIT

    // --- Odota valmis (poll AUDIT_STATUS) ---
    begin
      logic [COEFF_W-1:0] status;
      int wait_cycles;
      wait_cycles = 0; status = 0;
      while (!status[1] && wait_cycles < 1000) begin  // bit[1] = write_done sticky
        wb_read(10'h113, status);
        wait_cycles++;
      end
      if (!status[1]) begin
        $display("FAIL: audit-lokin kirjoitus ei valmistunut (wait_cycles=%0d)", wait_cycles);
        error_count++;
      end else begin
        $display("OK: audit-lokin kirjoitus valmis %0d Wishbone-syklin jalkeen", wait_cycles);
      end
    end

    // --- Lue jarjestysnumero ---
    begin
      logic [COEFF_W-1:0] seq;
      wb_read(10'h114, seq);
      if (seq !== 16'd0) begin
        $display("FAIL: write_seq=%0d, odotettu 0", seq);
        error_count++;
      end else $display("OK: write_seq=0 (ensimmainen merkinta)");
    end

    // --- Lue chain_hash takaisin 16 sanana, vertaa golden-referenssiin ---
    begin
      logic [255:0] read_back_chain;
      logic [COEFF_W-1:0] word;
      for (int w = 0; w < 16; w++) begin
        wb_write(10'h110, w[9:0]);  // AUDIT_WORD_SEL
        wb_read(10'h115, word);     // AUDIT_CHAIN_OUT
        read_back_chain[w*16 +: 16] = word;
      end
      if (read_back_chain !== golden_chain_hash) begin
        $display("FAIL: chain_hash EI TASMAA. RTL=%h golden=%h", read_back_chain, golden_chain_hash);
        error_count++;
      end else begin
        $display("OK: chain_hash tasmaa golden-referenssiin Wishbone-vaylan kautta (%h)", read_back_chain);
      end
    end

    // --- Sanity-tarkistus: NTT-datan kirjoitus/luku toimii yha samassa kaareessa ---
    begin
      logic [COEFF_W-1:0] readback;
      wb_write(10'h000, 16'd12345);
      wb_read(10'h000, readback);
      if (readback !== 16'd12345) begin
        $display("FAIL: NTT-datan luku/kirjoitus rikki - luettu %0d, odotettu 12345", readback);
        error_count++;
      end else $display("OK: NTT-datan luku/kirjoitus toimii yha samassa TAU-kaareessa");
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: TAU-Wishbone-integraatio - audit-loki + NTT-ydin samassa vaylassa");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
