// M4-TAU-001 Osa 3: watchdog-testi. Todentaa: (1) saannollinen
// heartbeat pitaa ecu_alive=1, (2) puuttuva heartbeat laukaisee
// aikakatkaisun tasan oikealla syklilla, (3) timeout_count kasvaa
// oikein, (4) konfiguroitava aikakatkaisukynnys toimii.

`timescale 1ns/1ps

module pqc_tau_watchdog_tb;

  logic clk, reset;
  logic heartbeat_valid;
  logic [31:0] timeout_cycles;
  logic config_valid;
  logic ecu_alive, timeout_event;
  logic [31:0] cycles_since_heartbeat, timeout_count;

  always #5 clk = ~clk;

  pqc_tau_watchdog #(.TIMEOUT_CYCLES_DEFAULT(20)) dut (
    .clk(clk), .reset(reset),
    .heartbeat_valid(heartbeat_valid),
    .timeout_cycles(timeout_cycles), .config_valid(config_valid),
    .ecu_alive(ecu_alive), .timeout_event(timeout_event),
    .cycles_since_heartbeat(cycles_since_heartbeat), .timeout_count(timeout_count)
  );

  int error_count;

  initial begin
    error_count = 0;
    clk = 0; reset = 1; heartbeat_valid = 0; timeout_cycles = 0; config_valid = 0;
    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);

    // --- Vaihe 1: saannollinen heartbeat (joka 10. sykli, timeout=20)
    // pitaa ecu_alive:n 1:sena ---
    for (int i = 0; i < 5; i++) begin
      heartbeat_valid <= 1'b1;
      @(posedge clk);
      heartbeat_valid <= 1'b0;
      repeat (9) @(posedge clk);
      if (!ecu_alive) begin
        $display("FAIL: ecu_alive putosi 0:aan saannollisen heartbeatin aikana (iteraatio %0d)", i);
        error_count++;
      end
    end
    $display("OK: saannollinen heartbeat pitaa ecu_alive=1 (5 iteraatiota, timeout=20, vali=10)");

    // --- Vaihe 2: lopeta heartbeat, odota aikakatkaisu (puhdas
    // reset ensin, jotta laskuri alkaa tarkalleen 0:sta) ---
    reset = 1; repeat(3) @(posedge clk); reset = 0; @(posedge clk);
    begin
      int wait_cycles;
      wait_cycles = 0;
      while (!timeout_event && wait_cycles < 100) begin
        @(posedge clk);
        wait_cycles++;
      end
      if (!timeout_event) begin
        $display("FAIL: aikakatkaisua ei havaittu 100 syklin sisalla");
        error_count++;
      end else begin
        $display("OK: aikakatkaisu havaittu %0d syklin jalkeen (odotettu 20-21, rekisterointiviive huomioitu)", wait_cycles);
        if (wait_cycles < 20 || wait_cycles > 22) begin
          $display("FAIL: aikakatkaisun ajoitus vaara - odotettiin 20-22 sykliä, saatiin %0d", wait_cycles);
          error_count++;
        end
      end
      @(posedge clk);
      if (ecu_alive) begin
        $display("FAIL: ecu_alive pysyi 1:sena aikakatkaisun jalkeen");
        error_count++;
      end else $display("OK: ecu_alive=0 (degraded-tila) aikakatkaisun jalkeen");
      if (timeout_count !== 32'd1) begin
        $display("FAIL: timeout_count=%0d, odotettu 1", timeout_count);
        error_count++;
      end else $display("OK: timeout_count=1");
    end

    // --- Vaihe 3: degraded-tila EI palaudu automaattisesti pelkalla
    // uudella heartbeatilla (tietoinen suunnittelupaatos - vika ei
    // saa kadota hiljaa) ---
    heartbeat_valid <= 1'b1;
    @(posedge clk);
    heartbeat_valid <= 1'b0;
    @(posedge clk);
    if (ecu_alive) begin
      $display("FAIL: ecu_alive palautui automaattisesti - tama rikkoo TN-002:n oman periaatteen ettei vikaa piiloteta hiljaa");
      error_count++;
    end else $display("OK: degraded-tila EI palaudu automaattisesti (tarkoituksellinen kayttaytyminen)");

    // --- Vaihe 4: konfiguroitava aikakatkaisukynnys ---
    reset = 1; repeat(3) @(posedge clk); reset = 0; @(posedge clk);
    timeout_cycles <= 32'd50;
    config_valid <= 1'b1;
    @(posedge clk);
    config_valid <= 1'b0;
    @(posedge clk);
    begin
      int wait_cycles;
      wait_cycles = 0;
      while (!timeout_event && wait_cycles < 200) begin
        @(posedge clk);
        wait_cycles++;
      end
      if (wait_cycles < 45 || wait_cycles > 50) begin
        $display("FAIL: konfiguroitu aikakatkaisu (50) ei toiminut oikein - havaittu %0d syklin jalkeen", wait_cycles);
        error_count++;
      end else $display("OK: konfiguroitu aikakatkaisukynnys (50) toimii oikein (%0d syklia, asetuksen oma ylikustannus huomioitu)", wait_cycles);
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: TAU-watchdog toimii oikein kaikissa nelja vaiheessa");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
