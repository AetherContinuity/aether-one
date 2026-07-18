// M4-ENCAPS-ORCH-001 audit-integraatiotesti: varmistaa etta Encaps
// kirjaa AUDIT-lokiin kaksi tapahtumaa (kaynnistys + valmistuminen)
// omilla, KeyGenista/Decapsista erillisilla tunnistehasheilla.

`timescale 1ns/1ps

module pqc_tau_encaps_audit_tb;

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

  localparam logic [255:0] ENCAPS_STARTED_HASH =
    256'hd017a92c25b5e1389673606647ee92bc4aa5d7a22597bb9f06ebc2928b143e1;
  localparam logic [255:0] ENCAPS_COMPLETED_HASH =
    256'h544b25411db9aea3616f97bb9e694f831ba98f9afdbbd4d50a3dcc7f519c10f;

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
    wb_write(11'h143, 16'd1);  // ENCAPS_START

    begin
      logic [COEFF_W-1:0] status;
      int wait_cycles;
      wait_cycles = 0; status = 0;
      while (!status[1] && wait_cycles < 30000) begin
        wb_read(11'h144, status);
        wait_cycles++;
      end
      if (!status[1]) begin
        $display("FAIL: Encaps ei valmistunut");
        error_count++;
      end else $display("OK: Encaps valmis %0d syklin jalkeen", wait_cycles);
    end

    repeat (100) @(posedge clk);

    begin
      logic [COEFF_W-1:0] log_seq;
      wb_read(11'h114, log_seq);
      if (log_seq !== 16'd1) begin
        $display("FAIL: audit-lokin viimeisin seq=%0d, odotettu 1", log_seq);
        error_count++;
      end else $display("OK: audit-loki sisaltaa tasan kaksi merkintaa");
    end

    begin
      logic [255:0] decision0, decision1;
      logic [COEFF_W-1:0] word;

      wb_write(11'h116, 16'd0);
      for (int w = 0; w < 16; w++) begin
        wb_write(11'h110, w[10:0]);
        wb_read(11'h119, word);
        decision0[w*16+:16] = word;
      end

      wb_write(11'h116, 16'd1);
      for (int w = 0; w < 16; w++) begin
        wb_write(11'h110, w[10:0]);
        wb_read(11'h119, word);
        decision1[w*16+:16] = word;
      end

      if (decision0 === ENCAPS_STARTED_HASH) $display("OK: seq=0 on ENCAPS_STARTED-tapahtuma");
      else begin $display("FAIL: seq=0 ei tasmaa ENCAPS_STARTED-hashiin"); error_count++; end

      if (decision1 === ENCAPS_COMPLETED_HASH) $display("OK: seq=1 on ENCAPS_COMPLETED-tapahtuma");
      else begin $display("FAIL: seq=1 ei tasmaa ENCAPS_COMPLETED-hashiin"); error_count++; end
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: Encaps kirjaa audit-lokiin oikeat, omat tapahtumat (STARTED+COMPLETED)");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
