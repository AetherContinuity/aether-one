// pqc_tau_watchdog.sv
//
// M4-TAU-001 Osa 3: watchdog/heartbeat-logiikka ECU<->TAU-
// viestintaa varten, TN-002-arkkitehtuurin mukaisesti
// (https://aethercontinuity.org/supplements/tn-002-dcein.html,
// "Watchdog System" -kohta):
//
// "Heartbeat monitoring between ECU and TAU ensures that failures
// are detected and logged even when the operational unit is
// compromised. The system enters degraded mode gracefully rather
// than failing silently."
//
// PERIAATE: ECU kirjoittaa saannollisesti heartbeat-signaalin.
// TAU seuraa sykleja edellisesta heartbeatista. Jos aikakatkaisu
// ylittyy, TAU:n oma tila siirtyy "degraded"-tilaan (EI kaadu, EI
// pysahdy - vain merkitsee tilan) JA laukaisee automaattisen
// audit-loki-merkinnan (integroituu M4-TAU-001 Osa 1/2:n audit-
// lokiin) - "vika havaitaan JA lokitetaan" TN-002:n oman vaatimuksen
// mukaisesti.

`timescale 1ns/1ps

module pqc_tau_watchdog #(
    parameter int TIMEOUT_CYCLES_DEFAULT = 1000  // oletusarvo, muutettavissa
)(
    input  logic clk,
    input  logic reset,

    // --- ECU:n oma heartbeat-kirjoitus ---
    input  logic heartbeat_valid,   // 1 sykli: ECU ilmoittaa olevansa elossa

    // --- Konfiguraatio ---
    input  logic [31:0] timeout_cycles,  // aikakatkaisukynnys sykleina
    input  logic config_valid,            // 1 sykli: paivita timeout_cycles

    // --- Tila ---
    output logic ecu_alive,                 // 0 = degraded-tila (aikakatkaisu tapahtunut)
    output logic timeout_event,             // 1 SYKLI: uusi aikakatkaisu havaittu TASSA syklissa
    output logic [31:0] cycles_since_heartbeat,
    output logic [31:0] timeout_count        // montako aikakatkaisua havaittu yhteensa
);

  logic [31:0] active_timeout;
  logic [31:0] counter;

  always_ff @(posedge clk) begin
    timeout_event <= 1'b0;

    if (reset) begin
      active_timeout <= TIMEOUT_CYCLES_DEFAULT;
      counter <= 32'd0;
      ecu_alive <= 1'b1;
      timeout_count <= 32'd0;
    end else begin
      if (config_valid) active_timeout <= timeout_cycles;

      if (heartbeat_valid) begin
        counter <= 32'd0;
        // HUOM: heartbeat EI automaattisesti palauta ecu_alive:a
        // 1:ksi - TAMA VAATII EKSPLISIITTISEN "degraded-tilan
        // kuittauksen" (esim. ohjelmiston oma toimenpide), koska
        // TN-002:n oma periaate on ettei vikaa piiloteta hiljaa -
        // kertaalleen havaittu aikakatkaisu jaa nakyviin kunnes
        // joku nimenomaisesti kuittaa sen.
      end else if (counter < active_timeout) begin
        counter <= counter + 32'd1;
      end else begin
        // Aikakatkaisu tapahtui TASSA syklissa
        if (ecu_alive) begin
          ecu_alive <= 1'b0;
          timeout_event <= 1'b1;
          timeout_count <= timeout_count + 32'd1;
        end
      end
    end
  end

  assign cycles_since_heartbeat = counter;

endmodule
