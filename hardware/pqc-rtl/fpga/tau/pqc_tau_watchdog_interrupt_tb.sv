// M4-TAU-001 watchdog-integraatio: testaa etta watchdog-aikakatkaisu
// KESKEN KeyGenin oman ajon lokittuu audit-lokiin OMalla, erillisella
// tunnistehashilla - TN-002:n oma vaatimus: vika lokitetaan vaikka
// kayttoyksikko (ECU) on lakannut toimimasta (ei enaa laheta
// heartbeatia).

`timescale 1ns/1ps

module pqc_tau_watchdog_interrupt_tb;

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

    // --- Aseta LYHYT watchdog-aikakatkaisu (100 sykliä) - KeyGen
    // vaatii TUHANSIA sykleja, joten watchdog laukeaa VARMASTI
    // ensin. ---
    wb_write(11'h128, 16'd1000);  // WATCHDOG_TIMEOUT_CONFIG

    // --- Anna ensin heartbeat (ECU "elossa"), sitten lopeta - EI
    // enaa heartbeatia taman jalkeen (simuloi ECU:n vaarantumista). ---
    wb_write(11'h127, 16'd1);  // HEARTBEAT

    // --- Kirjoita seed ja kaynnista KeyGen ---
    for (int w = 0; w < 16; w++) begin
      wb_write(11'h120, w[10:0]);
      wb_write(11'h121, d_seed[w*16+:16]);
    end
    for (int w = 0; w < 16; w++) begin
      wb_write(11'h120, w[10:0]);
      wb_write(11'h122, z_seed[w*16+:16]);
    end
    wb_write(11'h123, 16'd1);  // KEYGEN_START
    $display("KeyGen kaynnistetty, EI enaa heartbeatia (ECU 'vaarantunut')");

    // --- Odota etta watchdog laukeaa (WATCHDOG_STATUS bit[0]=ecu_alive putoaa 0:aan) ---
    begin
      logic [COEFF_W-1:0] wd_status;
      int wait_cycles;
      wait_cycles = 0; wd_status = 16'd1;
      while (wd_status[0] && wait_cycles < 2000) begin
        wb_read(11'h129, wd_status);
        wait_cycles++;
      end
      if (wd_status[0]) begin
        $display("FAIL: watchdog ei lauennut 2000 syklin sisalla");
        error_count++;
      end else $display("OK: watchdog laukesi (ecu_alive=0) %0d syklin jalkeen", wait_cycles);
    end

    // --- Odota hetki lisaa jotta audit-kirjoitus ehtii valmistua ---
    repeat (100) @(posedge clk);

    // --- Tarkista audit-loki: pitaisi olla KAKSI merkintaa
    // (KeyGen kaynnistetty + watchdog keskeytti) - EI "KeyGen valmis",
    // koska sita ei koskaan saavutettu. ---
    begin
      logic [COEFF_W-1:0] log_seq;
      wb_read(11'h114, log_seq);
      if (log_seq !== 16'd1) begin
        $display("FAIL: audit-lokin viimeisin seq=%0d, odotettu 1 (kaksi merkintaa)", log_seq);
        error_count++;
      end else $display("OK: audit-loki sisaltaa tasan kaksi merkintaa");
    end

    // --- Lue toinen merkinta (seq=1) ja tarkista etta se on
    // NIMENOMAAN watchdog-keskeytys, ei "KeyGen valmis" ---
    begin
      logic [COEFF_W-1:0] rd_seq_reg;
      logic [255:0] decision_hash_readback;
      logic [COEFF_W-1:0] word;
      localparam logic [255:0] WD_INTERRUPT_HASH =
        256'h7d07634cc39e92beabe29262bd672fd15156917f4cfb96b60531dfe36d9e476;
      localparam logic [255:0] KEYGEN_COMPLETED_HASH =
        256'hb634916025159880127a357fd392702fdeab5c38a97e47f846aa588e6617953;

      wb_write(11'h116, 16'd1);  // AUDIT_READ_SEQ = 1
      for (int w = 0; w < 16; w++) begin
        wb_write(11'h110, w[10:0]);  // AUDIT_WORD_SEL
        wb_read(11'h119, word);      // AUDIT_READ_DECISION
        decision_hash_readback[w*16+:16] = word;
      end

      if (decision_hash_readback === WD_INTERRUPT_HASH) begin
        $display("OK: toinen audit-merkinta ON nimenomaan 'watchdog keskeytti' -tapahtuma");
      end else if (decision_hash_readback === KEYGEN_COMPLETED_HASH) begin
        $display("FAIL: toinen audit-merkinta on 'KeyGen valmis' - vaikka watchdog laukesi ensin!");
        error_count++;
      end else begin
        $display("FAIL: toinen audit-merkinta ei tasmaa kumpaankaan odotettuun hashiin");
        error_count++;
      end
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: watchdog-keskeytys lokittuu oikein audit-lokiin, erotettuna KeyGenin omasta valmistumisesta");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
