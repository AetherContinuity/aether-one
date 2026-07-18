// M4-DECAPS-ORCH-001 audit-integraatiotesti: varmistaa etta Decaps
// kirjaa AUDIT-lokiin kaksi tapahtumaa (kaynnistys + valmistuminen)
// omilla, KeyGenista erillisilla tunnistehasheilla.

`timescale 1ns/1ps

module pqc_tau_decaps_audit_tb;

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

  localparam logic [255:0] DECAPS_STARTED_HASH =
    256'h17a30f6b265de08941701b60853803f3765366e6813c8ff7049c65d0f7443a5;
  localparam logic [255:0] DECAPS_COMPLETED_HASH =
    256'hc8e62f26f38dfe54ea7377f2d1f9e095416dab0e7283e492f31549c78b3563c8;

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

    for (int w = 0; w < 384; w++) begin
      wb_write(11'h130, w[10:0]);
      wb_write(11'h131, c[w*16+:16]);
    end
    for (int w = 0; w < 816; w++) begin
      wb_write(11'h130, w[10:0]);
      wb_write(11'h132, dk[w*16+:16]);
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
        $display("FAIL: Decaps ei valmistunut");
        error_count++;
      end else $display("OK: Decaps valmis %0d syklin jalkeen", wait_cycles);
    end

    // Odota etta audit-lokin viimeinen kirjoitus (DECAPS_COMPLETED)
    // ehtii valmistua - sama "kadonnut pulssi" -harkinta kuin
    // aiemmin loydetty M4-SoC-001:ssa.
    repeat (100) @(posedge clk);

    // Audit-lokin pitaisi sisaltaa tasan kaksi merkintaa: DECAPS_STARTED (seq=0), DECAPS_COMPLETED (seq=1)
    begin
      logic [COEFF_W-1:0] log_seq;
      wb_read(11'h114, log_seq);
      if (log_seq !== 16'd1) begin
        $display("FAIL: audit-lokin viimeisin seq=%0d, odotettu 1", log_seq);
        error_count++;
      end else $display("OK: audit-loki sisaltaa tasan kaksi merkintaa");
    end

    // Tarkista molemmat merkinnat
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

      if (decision0 === DECAPS_STARTED_HASH) $display("OK: seq=0 on DECAPS_STARTED-tapahtuma");
      else begin $display("FAIL: seq=0 ei tasmaa DECAPS_STARTED-hashiin"); error_count++; end

      if (decision1 === DECAPS_COMPLETED_HASH) $display("OK: seq=1 on DECAPS_COMPLETED-tapahtuma");
      else begin $display("FAIL: seq=1 ei tasmaa DECAPS_COMPLETED-hashiin"); error_count++; end
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: Decaps kirjaa audit-lokiin oikeat, omat tapahtumat (STARTED+COMPLETED)");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
