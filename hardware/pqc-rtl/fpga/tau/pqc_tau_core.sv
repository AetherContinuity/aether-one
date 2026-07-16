// pqc_tau_core.sv
//
// M4-TAU-001 Osa 4: yhdistaa watchdogin (Osa 3) ja audit-lokin
// (Osa 1) - TN-002:n oma vaatimus: "failures are detected and
// logged even when the operational unit is compromised."
//
// Kun watchdog havaitsee aikakatkaisun (timeout_event), TAMA MODUULI
// laukaisee AUTOMAATTISESTI audit-loki-merkinnan KIINTEALLA
// tunnistehashilla (SHA3-256("WATCHDOG_TIMEOUT_EVENT"), pack_bytes-
// konvention mukaisesti) - EI riipu ECU:sta lainkaan, koska
// TN-002:n oma periaate on etta vika lokitetaan VAIKKA ECU on
// vaarantunut (watchdog-laukaisu ei tarvitse ECU:n omaa toimintaa).
//
// Prioriteetti: watchdog-laukaisu > ECU:n oma kirjoituspyynto (jos
// molemmat sattuvat samalle syklille - harvinainen reunatapaus,
// mutta turvakriittinen tapahtuma ei saa jaada odottamaan).

`timescale 1ns/1ps

module pqc_tau_core #(
    parameter int LOG_DEPTH = 64,
    parameter int TIMEOUT_CYCLES_DEFAULT = 1000
)(
    input  logic clk,
    input  logic reset,

    // --- ECU:n oma kirjoituspyynto ---
    input  logic ecu_write_valid,
    input  logic [255:0] ecu_decision_hash,
    output logic ecu_write_accepted,  // 1 sykli: ECU:n pyynto hyvaksyttiin (ei jaanyt watchdogin varjoon)

    // --- Heartbeat/watchdog ---
    input  logic heartbeat_valid,
    input  logic [31:0] timeout_cycles,
    input  logic config_valid,
    output logic ecu_alive,
    output logic timeout_event,
    output logic [31:0] cycles_since_heartbeat,
    output logic [31:0] timeout_count,

    // --- Audit-lokin tulokset (lapivienti) ---
    output logic write_busy,
    output logic write_done,
    output logic [7:0] write_seq,
    output logic [255:0] write_chain_hash,
    output logic write_was_watchdog_event,  // 1 sykli, write_done:n kanssa: TAMA merkinta oli watchdog-tapahtuma, ei ECU-paatos

    // --- Lukurajapinta (lapivienti) ---
    input  logic [7:0] read_seq,
    output logic [255:0] read_chain_hash,
    output logic [255:0] read_decision_hash,
    output logic read_entry_valid,
    output logic [7:0] log_count,
    output logic log_full
);

  // Kiintea tunnistehash watchdog-tapahtumille: SHA3-256("WATCHDOG_TIMEOUT_EVENT"),
  // pack_bytes-konvention mukaisesti (tavu 0 = vahiten merkitseva tavu) -
  // sama konventio kuin M4-TAU-001 Osa 1:ssa (ks. audit_log_golden.txt).
  localparam logic [255:0] WATCHDOG_SENTINEL_HASH =
    256'h79bcdf82e81876b2db2f9fd1a921bd78c3fb969faf7c911f4439814927b39232;

  pqc_tau_watchdog #(.TIMEOUT_CYCLES_DEFAULT(TIMEOUT_CYCLES_DEFAULT)) watchdog (
    .clk(clk), .reset(reset),
    .heartbeat_valid(heartbeat_valid),
    .timeout_cycles(timeout_cycles), .config_valid(config_valid),
    .ecu_alive(ecu_alive), .timeout_event(timeout_event),
    .cycles_since_heartbeat(cycles_since_heartbeat), .timeout_count(timeout_count)
  );

  // --- Kirjoitusarbitrointi: watchdog > ECU ---
  logic arb_write_valid;
  logic [255:0] arb_decision_hash;
  logic pending_watchdog_write;

  always_ff @(posedge clk) begin
    if (reset) begin
      pending_watchdog_write <= 1'b0;
      ecu_write_accepted <= 1'b0;
    end else begin
      ecu_write_accepted <= 1'b0;
      if (timeout_event) begin
        pending_watchdog_write <= 1'b1;
      end else if (write_busy == 1'b0 && pending_watchdog_write) begin
        // watchdog-kirjoitus lahetetty audit-lokiin (kasitellaan alla)
        pending_watchdog_write <= 1'b0;
      end
    end
  end

  always_comb begin
    if (timeout_event || pending_watchdog_write) begin
      arb_write_valid = 1'b1;
      arb_decision_hash = WATCHDOG_SENTINEL_HASH;
    end else begin
      arb_write_valid = ecu_write_valid;
      arb_decision_hash = ecu_decision_hash;
    end
  end

  logic write_was_watchdog_event_reg;
  always_ff @(posedge clk) begin
    if (reset) begin
      write_was_watchdog_event_reg <= 1'b0;
    end else if (arb_write_valid && !write_busy) begin
      write_was_watchdog_event_reg <= (timeout_event || pending_watchdog_write);
      if (!(timeout_event || pending_watchdog_write)) ecu_write_accepted <= 1'b1;
    end
  end
  assign write_was_watchdog_event = write_was_watchdog_event_reg && write_done;

  pqc_tau_audit_log #(.LOG_DEPTH(LOG_DEPTH)) audit (
    .clk(clk), .reset(reset),
    .write_valid(arb_write_valid), .decision_hash(arb_decision_hash),
    .write_busy(write_busy), .write_done(write_done),
    .write_seq(write_seq), .write_chain_hash(write_chain_hash),
    .read_seq(read_seq), .read_chain_hash(read_chain_hash),
    .read_decision_hash(read_decision_hash), .read_entry_valid(read_entry_valid),
    .log_count(log_count), .log_full(log_full)
  );

endmodule
