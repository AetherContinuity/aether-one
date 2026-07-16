// M4-SoC-001: Wishbone-vaylakaareen testi. Ajaa TASMALLEEN saman
// koko 7-tasoisen NTT-laskennan kuin muut testit, MUTTA KAIKKI
// vuorovaikutus (data-alustus, ohjaus, tuloksen luku) tapahtuu
// PUHTAASTI Wishbone-syklien kautta - ei hierarkkista pikapaasyaa.

`timescale 1ns/1ps

module pqc_ntt_wishbone_tb;

  localparam int COEFF_W = 16;
  localparam int SPAD_AW = 9;

  logic clk, rst;
  logic [8:0] wb_adr;
  logic [COEFF_W-1:0] wb_dat_i, wb_dat_o;
  logic wb_we, wb_stb, wb_cyc, wb_ack;

  always #5 clk = ~clk;

  pqc_ntt_wishbone_wrapper #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW)) dut (
    .clk(clk), .rst(rst),
    .wb_adr_i(wb_adr), .wb_dat_i(wb_dat_i), .wb_dat_o(wb_dat_o),
    .wb_we_i(wb_we), .wb_stb_i(wb_stb), .wb_cyc_i(wb_cyc), .wb_ack_o(wb_ack)
  );

  logic [COEFF_W-1:0] init_mem [0:255];
  logic [COEFF_W-1:0] expect_mem [0:255];

  task automatic wb_write(input [8:0] addr, input [COEFF_W-1:0] data);
    begin
      wb_adr <= addr; wb_dat_i <= data; wb_we <= 1'b1; wb_stb <= 1'b1; wb_cyc <= 1'b1;
      @(posedge clk);
      while (!wb_ack) @(posedge clk);
      wb_stb <= 1'b0; wb_cyc <= 1'b0; wb_we <= 1'b0;
      @(posedge clk);
    end
  endtask

  task automatic wb_read(input [8:0] addr, output [COEFF_W-1:0] data);
    begin
      wb_adr <= addr; wb_we <= 1'b0; wb_stb <= 1'b1; wb_cyc <= 1'b1;
      @(posedge clk);
      while (!wb_ack) @(posedge clk);
      data = wb_dat_o;
      wb_stb <= 1'b0; wb_cyc <= 1'b0;
      @(posedge clk);
    end
  endtask

  int fh, length, base0, zeta0, base1, zeta1, scan_ok;
  int error_count;

  initial begin
    error_count = 0;
    clk = 0; rst = 1; wb_adr = 0; wb_dat_i = 0; wb_we = 0; wb_stb = 0; wb_cyc = 0;

    $readmemh("vectors/full_init.memh", init_mem);

    repeat (3) @(posedge clk);
    rst = 0;
    @(posedge clk);

    // --- Kirjoita kaikki 256 alkuarvoa Wishbone-kirjoituksilla ---
    for (int i = 0; i < 256; i++) wb_write(i[8:0], init_mem[i]);
    $display("Kaikki 256 alkuarvoa kirjoitettu Wishbone-vaylan kautta");

    // --- Aja koko 7-tasoinen NTT: taso 6 ensin ---
    fh = $fopen("vectors/full_level6_zeta.txt", "r");
    scan_ok = $fscanf(fh, "%d\n", zeta0);
    $fclose(fh);
    wb_write(9'h102, 8'd128);        // PAIR_DIST
    wb_write(9'h103, 9'd0);          // BASE_ADDR_LANE0
    wb_write(9'h104, 9'd64);         // BASE_ADDR_LANE1
    wb_write(9'h105, zeta0[15:0]);   // ZETA_LANE0
    wb_write(9'h106, zeta0[15:0]);   // ZETA_LANE1
    wb_write(9'h101, 8'd64);         // COUNT
    wb_write(9'h100, 16'b01);        // CTRL: start=1, mode=0
    repeat(5) @(posedge clk);

    begin
      logic [COEFF_W-1:0] status;
      int wait_cycles;
      wait_cycles = 0;
      status = 0;
      while (!status[0] && wait_cycles < 5000) begin
        wb_read(9'h107, status);
        wait_cycles++;
      end
      if (!status[0]) begin $display("FAIL: taso 6 ei valmistunut"); error_count++; end
    end

    // --- Tasot 5..0 ---
    fh = $fopen("vectors/full_schedule.txt", "r");
    scan_ok = 5;
    begin
      int iter_num;
      iter_num = 0;
      while (!$feof(fh) && scan_ok == 5) begin
        scan_ok = $fscanf(fh, "%d %d %d %d %d\n", length, base0, zeta0, base1, zeta1);
        if (scan_ok == 5) begin
          iter_num++;
          wb_write(9'h102, length[7:0]);
          wb_write(9'h103, base0[8:0]);
          wb_write(9'h104, base1[8:0]);
          wb_write(9'h105, zeta0[15:0]);
          wb_write(9'h106, zeta1[15:0]);
          wb_write(9'h101, length[7:0]);
          wb_write(9'h100, 16'b01);
            repeat(3) @(posedge clk);

        begin
          logic [COEFF_W-1:0] status;
          int wait_cycles;
          wait_cycles = 0; status = 0;
          while (!status[0] && wait_cycles < 5000) begin
            wb_read(9'h107, status);
            wait_cycles++;
          end
          if (!status[0]) begin
            $display("FAIL: taso (length=%0d) ei valmistunut, wait_cycles=%0d, status=%0d, core.stage_done=%0b, lane0.state=%0d, lane1.state=%0d", length, wait_cycles, status, dut.core.stage_done, dut.core.lane0.state, dut.core.lane1.state);
            error_count++;
          end
        end
      end
    end
    end
    $fclose(fh);
    $display("Koko 7-tasoinen NTT ajettu taysin Wishbone-vaylan kautta");

    // --- Lue kaikki 256 tulosta Wishbone-vaylan kautta, vertaa golden-malliin ---
    $readmemh("vectors/full_expect.memh", expect_mem);
    for (int i = 0; i < 256; i++) begin
      logic [COEFF_W-1:0] got;
      wb_read(i[8:0], got);
      if (got !== expect_mem[i]) begin
        $display("FAIL: osoite %0d = %0d, odotettu %0d", i, got, expect_mem[i]);
        error_count++;
      end
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: koko 7-tasoinen NTT TAYSIN Wishbone-vaylan kautta tasmaa golden-malliin");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
