// M4-ENCAPS-ORCH-001 Wishbone-integraatiotesti.

`timescale 1ns/1ps

module pqc_tau_encaps_wishbone_tb;

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
  logic [8*800-1:0] ek;
  logic [255:0] m_msg, K_expect;
  logic [8*768-1:0] c_expect;

  initial begin
    error_count = 0;
    clk = 0; rst = 1; wb_adr = 0; wb_dat_i = 0; wb_we = 0; wb_stb = 0; wb_cyc = 0;

    fh = $fopen("fpga/tau/encaps_top_e2e_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", ek);
    scan_ok = $fscanf(fh, "%h\n", m_msg);
    scan_ok = $fscanf(fh, "%h\n", K_expect);
    scan_ok = $fscanf(fh, "%h\n", c_expect);
    $fclose(fh);

    repeat (3) @(posedge clk);
    rst = 0;
    @(posedge clk);

    for (int w = 0; w < 400; w++) begin
      wb_write(11'h140, w[10:0]);
      wb_write(11'h141, ek[w*16+:16]);
    end
    for (int w = 0; w < 16; w++) begin
      wb_write(11'h140, w[10:0]);
      wb_write(11'h142, m_msg[w*16+:16]);
    end
    $display("ECU: ek + m kirjoitettu Wishbone-vaylan kautta");

    wb_write(11'h143, 16'd1);  // ENCAPS_START
    $display("ECU: ENCAPS_START laukaistu");

    begin
      logic [COEFF_W-1:0] status;
      int wait_cycles;
      wait_cycles = 0; status = 0;
      while (!status[1] && wait_cycles < 30000) begin
        wb_read(11'h144, status);  // ENCAPS_STATUS
        wait_cycles++;
      end
      if (!status[1]) begin
        $display("FAIL: Encaps ei valmistunut (wait_cycles=%0d)", wait_cycles);
        error_count++;
      end else $display("OK: Encaps valmis %0d Wishbone-syklin jalkeen", wait_cycles);
    end

    begin
      logic [255:0] K_readback;
      logic [COEFF_W-1:0] word;
      for (int w = 0; w < 16; w++) begin
        wb_write(11'h140, w[10:0]);
        wb_read(11'h145, word);  // ENCAPS_K_OUT
        K_readback[w*16+:16] = word;
      end
      if (K_readback === K_expect) $display("PASS: K tasmaa taydellisesti Wishbone-vaylan kautta luettuna");
      else begin $display("FAIL: K EI tasmaa"); error_count++; end
    end

    begin
      logic [8*768-1:0] c_readback;
      logic [COEFF_W-1:0] word;
      for (int w = 0; w < 384; w++) begin
        wb_write(11'h140, w[10:0]);
        wb_read(11'h146, word);  // ENCAPS_C_OUT
        c_readback[w*16+:16] = word;
      end
      if (c_readback === c_expect) $display("PASS: c tasmaa taydellisesti Wishbone-vaylan kautta luettuna");
      else begin $display("FAIL: c EI tasmaa"); error_count++; end
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: Encaps-Wishbone-integraatio - ECU->Wishbone->Encaps->ECU koko ketju toimii");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
