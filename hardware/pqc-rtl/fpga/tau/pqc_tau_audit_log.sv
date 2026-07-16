// pqc_tau_audit_log.sv
//
// M4-TAU-001: D4-yhteensopiva (Audit Continuity) hash-ketjutettu
// audit-loki TAU:lle (Trust Anchor Unit), TN-002-arkkitehtuurin
// mukaisesti (https://aethercontinuity.org/supplements/tn-002-dcein.html).
//
// KAYTTAA UUDELLEEN jo olemassa olevaa, todennettua SHA3-256-ydinta
// (pqc_sha3_256.sv, M3 Issue #12) hash-ketjutukseen - ei uutta
// kryptografista primitiivia.
//
// PERIAATE: jokainen loki-merkinta ketjuttaa edellisen merkinnan
// chain_hash:in uuteen hashiin, muodostaen muuttumattoman (append-
// only) ketjun - vastaavaa perustaa kuin blockchain-tyylinen
// hash-ketju, mutta paikallinen eika hajautettu (D4:n oma vaatimus:
// paikallinen, muuttumaton audit-loki + deferred reconciliation).
//
// chain_hash[n] = SHA3-256(chain_hash[n-1] || decision_hash[n] || seq[n])
//
// TAYSI paatoksen ALLEKIRJOITUS (TN-002:n kuvaama "ECU signs decision")
// vaatii Dilithiumia (M5-DILITHIUM-001, ei viela olemassa RTL:na).
// TASSA VAIHEESSA decision_hash on ECU:n toimittama HASH paatoksesta
// (esim. SHA3-256(paatosdata)) - EI viela allekirjoitettu Dilithium-
// signaturilla. Tama on TIETOISESTI rajattu, dokumentoitu valivaihe.

`timescale 1ns/1ps

module pqc_tau_audit_log #(
    parameter int LOG_DEPTH = 64  // tallennettavien merkintöjen maara
                                    // (tutkimusprototyyppi - tuotanto-
                                    // versio tarvitsisi paljon suuremman,
                                    // ulkoiseen muistiin kirjoittavan
                                    // version)
)(
    input  logic clk,
    input  logic reset,

    // --- ECU:n oma kirjoitusrajapinta: uusi paatoksen commitment ---
    input  logic write_valid,
    input  logic [255:0] decision_hash,   // ECU:n toimittama hash paatoksesta
    output logic write_busy,               // 1 = hash-laskenta kaynnissa
    output logic write_done,               // 1 sykli: uusi merkinta valmis
    output logic [7:0] write_seq,          // taman merkinnan jarjestysnumero
    output logic [255:0] write_chain_hash, // taman merkinnan chain_hash

    // --- Lukurajapinta (deferred reconciliation) ---
    input  logic [7:0] read_seq,
    output logic [255:0] read_chain_hash,
    output logic [255:0] read_decision_hash,
    output logic read_entry_valid,         // 1 = taman seq:in merkinta on olemassa

    // --- Tila ---
    output logic [7:0] log_count,          // montako merkintaa kirjoitettu yhteensa
    output logic log_full                  // 1 = LOG_DEPTH saavutettu (kiertava puskuri kirjoittaa yli)
);

  // --- Tallennusrakenne: kaksi rinnakkaista taulukkoa (chain_hash,
  // decision_hash) per merkinta. Tutkimusprototyyppi - ei viela
  // BRAM-optimoitu (M4-FPGA-002/003:n oma metodologia sovellettaisiin
  // TASSA, kun tuotantointegraatio harkitaan). ---
  logic [255:0] chain_hash_mem [0:LOG_DEPTH-1];
  logic [255:0] decision_hash_mem [0:LOG_DEPTH-1];
  logic entry_valid_mem [0:LOG_DEPTH-1];

  logic [255:0] current_chain_head;
  logic [7:0] seq_counter;

  // --- SHA3-256-ytimen uudelleenkaytto hash-ketjutukseen ---
  // Syote: chain_hash[n-1] (256b) || decision_hash[n] (256b) || seq[n] (8b)
  // = 520 bittia = 65 tavua, mahtuu YHTEEN 136-tavun lohkoon (MAX_BLOCKS=1).
  logic sha3_start, sha3_done;
  logic [8*136-1:0] sha3_msg_in;
  logic [255:0] sha3_digest;

  assign sha3_msg_in = {
    {(8*136-520){1'b0}},  // taytto nollilla (MAX_BLOCKS=1 vaatii koko leveyden)
    seq_counter, decision_hash_reg, current_chain_head
  };

  logic [255:0] decision_hash_reg;

  pqc_sha3_256 #(.MAX_BLOCKS(1)) hash_core (
    .clk(clk), .reset(reset), .start(sha3_start),
    .msg_in(sha3_msg_in), .msg_len_bytes(16'd65),
    .digest_out(sha3_digest), .done(sha3_done)
  );

  typedef enum logic [1:0] {S_IDLE, S_HASHING, S_COMMIT} state_e;
  state_e state;

  always_ff @(posedge clk) begin
    if (reset) begin
      state <= S_IDLE;
      current_chain_head <= 256'b0;  // "genesis" - kaikki nollia
      seq_counter <= 8'd0;
      sha3_start <= 1'b0;
      write_done <= 1'b0;
      write_busy <= 1'b0;
      log_count <= 8'd0;
      log_full <= 1'b0;
      for (int i = 0; i < LOG_DEPTH; i++) entry_valid_mem[i] <= 1'b0;
    end else begin
      write_done <= 1'b0;
      sha3_start <= 1'b0;

      case (state)
        S_IDLE: begin
          write_busy <= 1'b0;
          if (write_valid) begin
            decision_hash_reg <= decision_hash;
            sha3_start <= 1'b1;
            write_busy <= 1'b1;
            state <= S_HASHING;
          end
        end

        S_HASHING: begin
          if (sha3_done) begin
            state <= S_COMMIT;
          end
        end

        S_COMMIT: begin
          // Talleta merkinta (kiertava puskuri: LOG_DEPTH ylitys
          // kirjoittaa vanhimman merkinnan paalle - tuotannossa tama
          // vaatisi ulkoisen muistin/reconciliationin ENNEN ylikirjoitusta)
          chain_hash_mem[seq_counter % LOG_DEPTH] <= sha3_digest;
          decision_hash_mem[seq_counter % LOG_DEPTH] <= decision_hash_reg;
          entry_valid_mem[seq_counter % LOG_DEPTH] <= 1'b1;

          current_chain_head <= sha3_digest;
          write_chain_hash <= sha3_digest;
          write_seq <= seq_counter;
          write_done <= 1'b1;
          write_busy <= 1'b0;

          seq_counter <= seq_counter + 8'd1;
          if (log_count < LOG_DEPTH[7:0]) log_count <= log_count + 8'd1;
          else log_full <= 1'b1;

          state <= S_IDLE;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

  // --- Lukurajapinta: kombinatorinen (yksinkertaisuuden vuoksi
  // taman tutkimusprototyypin osalta) ---
  always_comb begin
    read_chain_hash    = chain_hash_mem[read_seq % LOG_DEPTH];
    read_decision_hash = decision_hash_mem[read_seq % LOG_DEPTH];
    read_entry_valid   = entry_valid_mem[read_seq % LOG_DEPTH];
  end

endmodule
