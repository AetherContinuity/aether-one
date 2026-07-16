// M4-TAU-001 Osa 4: pqc_tau_core -testi. Todentaa: (1) ECU:n oma
// kirjoitus toimii normaalisti, (2) watchdog-aikakatkaisu laukaisee
// AUTOMAATTISESTI audit-loki-merkinnan kiintealla tunnistehashilla,
// (3) write_was_watchdog_event erottaa merkintatyypit oikein.

`timescale 1ns/1ps

module pqc_tau_core_tb;

  logic clk, reset;
  logic ecu_write_valid, ecu_write_accepted;
  logic [255:0] ecu_decision_hash;
  logic heartbeat_valid;
  logic [31:0] timeout_cycles;
  logic config_valid;
  logic ecu_alive, timeout_event;
  logic [31:0] cycles_since_heartbeat, timeout_count;
  logic write_busy, write_done;
  logic [7:0] write_seq;
  logic [255:0] write_chain_hash;
  logic write_was_watchdog_event;
  logic [7:0] read_seq;
  logic [255:0] read_chain_hash, read_decision_hash;
  logic read_entry_valid;
  logic [7:0] log_count;
  logic log_full;

  always #5 clk = ~clk;

  pqc_tau_core #(.LOG_DEPTH(64), .TIMEOUT_CYCLES_DEFAULT(20)) dut (
    .clk(clk), .reset(reset),
    .ecu_write_valid(ecu_write_valid), .ecu_decision_hash(ecu_decision_hash),
    .ecu_write_accepted(ecu_write_accepted),
    .heartbeat_valid(heartbeat_valid), .timeout_cycles(timeout_cycles), .config_valid(config_valid),
    .ecu_alive(ecu_alive), .timeout_event(timeout_event),
    .cycles_since_heartbeat(cycles_since_heartbeat), .timeout_count(timeout_count),
    .write_busy(write_busy), .write_done(write_done),
    .write_seq(write_seq), .write_chain_hash(write_chain_hash),
    .write_was_watchdog_event(write_was_watchdog_event),
    .read_seq(read_seq), .read_chain_hash(read_chain_hash),
    .read_decision_hash(read_decision_hash), .read_entry_valid(read_entry_valid),
    .log_count(log_count), .log_full(log_full)
  );

  localparam logic [255:0] WATCHDOG_SENTINEL =
    256'h79bcdf82e81876b2db2f9fd1a921bd78c3fb969faf7c911f4439814927b39232;

  int error_count;

  initial begin
    error_count = 0;
    clk = 0; reset = 1; ecu_write_valid = 0; ecu_decision_hash = 0;
    heartbeat_valid = 0; timeout_cycles = 0; config_valid = 0; read_seq = 0;
    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);

    // --- Vaihe 1: ECU:n oma kirjoitus (ei aikakatkaisua) ---
    heartbeat_valid <= 1'b1;
    @(posedge clk);
    heartbeat_valid <= 1'b0;
    @(posedge clk);

    ecu_decision_hash <= 256'hAABBCCDD_00000000_00000000_00000000_00000000_00000000_00000000_11223344;
    ecu_write_valid <= 1'b1;
    @(posedge clk);
    ecu_write_valid <= 1'b0;
    while (!write_done) @(posedge clk);
    if (write_was_watchdog_event) begin
      $display("FAIL: ECU:n oma kirjoitus merkittiin virheellisesti watchdog-tapahtumaksi");
      error_count++;
    end else $display("OK: ECU:n oma kirjoitus (seq=%0d) merkitty oikein ECU-paatokseksi", write_seq);
    @(posedge clk);

    // --- Vaihe 2: lopeta heartbeat, odota watchdog-aikakatkaisu ---
    // (heartbeat jo lopetettu vaiheen 1 jalkeen - ei uutta heartbeatia)
    begin
      int wait_cycles;
      wait_cycles = 0;
      while (!write_done && wait_cycles < 100) begin
        @(posedge clk);
        wait_cycles++;
      end
      if (!write_done) begin
        $display("FAIL: watchdog-tapahtuman audit-loki-merkinta ei valmistunut 100 syklin sisalla");
        error_count++;
      end else if (!write_was_watchdog_event) begin
        $display("FAIL: watchdog-aikakatkaisun jalkeinen merkinta EI ollut merkitty watchdog-tapahtumaksi");
        error_count++;
      end else if (write_chain_hash === 256'b0) begin
        $display("FAIL: watchdog-tapahtuman chain_hash on nolla - jotain meni pieleen");
        error_count++;
      end else begin
        $display("OK: watchdog-aikakatkaisu laukaisi AUTOMAATTISESTI audit-loki-merkinnan (seq=%0d), %0d syklin jalkeen", write_seq, wait_cycles);
      end
    end

    // --- Lue takaisin watchdog-merkinta, tarkista etta decision_hash == sentinel ---
    read_seq = 8'd1;  // toinen merkinta (seq=1), ensimmainen oli ECU:n oma (seq=0)
    #1;
    if (read_decision_hash !== WATCHDOG_SENTINEL) begin
      $display("FAIL: watchdog-merkinnan decision_hash ei tasmaa odotettuun sentinel-arvoon");
      $display("  luettu:    %h", read_decision_hash);
      $display("  odotettu:  %h", WATCHDOG_SENTINEL);
      error_count++;
    end else $display("OK: watchdog-merkinnan decision_hash tasmaa odotettuun sentinel-arvoon");

    if (log_count !== 8'd2) begin
      $display("FAIL: log_count=%0d, odotettu 2 (yksi ECU + yksi watchdog)", log_count);
      error_count++;
    end else $display("OK: log_count=2 (yksi ECU-paatos + yksi watchdog-tapahtuma)");

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: TAU-ydin - watchdog integroitu audit-lokiin oikein");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
