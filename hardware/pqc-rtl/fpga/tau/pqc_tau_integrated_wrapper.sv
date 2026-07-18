// pqc_tau_integrated_wrapper.sv
//
// M4-TAU-001 integraatio (2026-07-19): yhdistaa Wishbone-vaylan,
// ML-KEM.KeyGen-orkestraattorin (M4-MLKEM-ORCH-001), audit-lokin ja
// watchdogin YHDEKSI TAU-moduuliksi, TN-002-arkkitehtuurin mukaisesti.
//
// Kayttajan oma, sovittu integraatiojarjestys:
// 1. Wishbone -> KeyGen: START-rekisteri, BUSY/DONE-tilarekisteri
// 2. KeyGen -> audit-loki: "KeyGen kaynnistetty" ja "KeyGen valmis"
//    -tapahtumat KIINTEILLA tunnistehasheilla (EI kryptografista
//    avainmateriaalia lokiin)
// 3. ECU<->TAU-rajapinta: ECU kirjoittaa komennon, TAU suorittaa
//    KeyGenin, ECU lukee tuloksen takaisin
//
// OSOITEKARTTA (laajennus M4-SoC-001/M4-TAU-001-Osa2:n paalle):
//   0x000-0x0FF: NTT-data (M4-SoC-001)
//   0x100-0x107: NTT-ohjaus/tila (M4-SoC-001)
//   0x110-0x119: Audit-loki (M4-TAU-001 Osa 1/2)
//   0x120: KEYGEN_WORD_SEL   (kirjoitus: valitse sana 0-1023)
//   0x121: KEYGEN_D_SEED_IN  (kirjoitus: 16-bittinen sana d_seed-puskuriin[WORD_SEL])
//   0x122: KEYGEN_Z_SEED_IN  (kirjoitus: 16-bittinen sana z_seed-puskuriin[WORD_SEL])
//   0x123: KEYGEN_START      (kirjoitus, mika tahansa arvo: laukaisee KeyGenin)
//   0x124: KEYGEN_STATUS     (luku): [0]=busy [1]=done (sticky)
//   0x125: KEYGEN_EK_OUT     (luku): ek:n sana WORD_SEL (0-399)
//   0x126: KEYGEN_DK_OUT     (luku): dk:n sana WORD_SEL (0-815)

`timescale 1ns/1ps

module pqc_tau_integrated_wrapper #(
    parameter int COEFF_W = 16,
    parameter int SPAD_AW = 9,
    parameter int LOG_DEPTH = 64
)(
    input  logic clk,
    input  logic rst,

    input  logic [10:0] wb_adr_i,
    input  logic [COEFF_W-1:0] wb_dat_i,
    output logic [COEFF_W-1:0] wb_dat_o,
    input  logic wb_we_i,
    input  logic wb_stb_i,
    input  logic wb_cyc_i,
    output logic wb_ack_o
);

  // --- NTT-ytimen ohjausrekisterit (kuten M4-SoC-001:ssa) ---
  logic ctrl_start_pulse, ctrl_mode;
  logic [7:0] ctrl_count, ctrl_pair_dist;
  logic [SPAD_AW-1:0] ctrl_base_addr0, ctrl_base_addr1;
  logic [COEFF_W-1:0] ctrl_zeta0, ctrl_zeta1;
  logic stage_done, bank_conflict_detected;
  logic load_valid, read_en, read_valid;
  logic [7:0] load_addr, read_addr;
  logic [COEFF_W-1:0] load_data, read_data;

  pqc_ntt_stage_banked #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW),
                          .NTT_READ_LATENCY(1), .FPGA_BRINGUP(1)) core (
    .clk(clk), .reset(rst), .start(ctrl_start_pulse),
    .count(ctrl_count), .pair_dist(ctrl_pair_dist), .mode(ctrl_mode),
    .base_addr_lane0(ctrl_base_addr0), .base_addr_lane1(ctrl_base_addr1),
    .zeta_lane0(ctrl_zeta0), .zeta_lane1(ctrl_zeta1),
    .stage_done(stage_done), .bank_conflict_detected(bank_conflict_detected),
    .load_valid(load_valid), .load_addr(load_addr), .load_data(load_data),
    .read_en(read_en), .read_addr(read_addr), .read_valid(read_valid), .read_data(read_data)
  );

  // --- Audit-loki ---
  logic audit_write_valid, audit_write_busy, audit_write_done;
  logic [255:0] audit_decision_hash_buf;
  logic [7:0] audit_write_seq;
  logic [255:0] audit_write_chain_hash;
  logic [7:0] audit_read_seq;
  logic [255:0] audit_read_chain_hash, audit_read_decision_hash;
  logic audit_read_entry_valid;
  logic [7:0] audit_log_count;
  logic audit_log_full;

  pqc_tau_audit_log #(.LOG_DEPTH(LOG_DEPTH)) audit (
    .clk(clk), .reset(rst),
    .write_valid(audit_write_valid), .decision_hash(audit_decision_hash_buf),
    .write_busy(audit_write_busy), .write_done(audit_write_done),
    .write_seq(audit_write_seq), .write_chain_hash(audit_write_chain_hash),
    .read_seq(audit_read_seq), .read_chain_hash(audit_read_chain_hash),
    .read_decision_hash(audit_read_decision_hash), .read_entry_valid(audit_read_entry_valid),
    .log_count(audit_log_count), .log_full(audit_log_full)
  );

  // --- Watchdog (M4-TAU-001 Osa 3/4:n integrointi tahan kokonaisuuteen) ---
  logic heartbeat_valid;
  logic [31:0] wd_timeout_cycles;
  logic wd_config_valid;
  logic ecu_alive, wd_timeout_event;
  logic [31:0] wd_cycles_since_heartbeat, wd_timeout_count;

  pqc_tau_watchdog #(.TIMEOUT_CYCLES_DEFAULT(100000)) watchdog (
    .clk(clk), .reset(rst),
    .heartbeat_valid(heartbeat_valid),
    .timeout_cycles(wd_timeout_cycles), .config_valid(wd_config_valid),
    .ecu_alive(ecu_alive), .timeout_event(wd_timeout_event),
    .cycles_since_heartbeat(wd_cycles_since_heartbeat), .timeout_count(wd_timeout_count)
  );

  // --- Decaps (M4-DECAPS-ORCH-001) ---
  logic decaps_start, decaps_done;
  logic [8*768-1:0] decaps_c_buf;
  logic [8*1632-1:0] decaps_dk_buf;
  logic [255:0] decaps_K_final;
  logic decaps_match;

  pqc_mlkem_decaps_top #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW), .K(2)) decaps (
    .clk(clk), .reset(rst), .start(decaps_start),
    .c_in(decaps_c_buf), .dk_in(decaps_dk_buf),
    .done(decaps_done), .K_final_out(decaps_K_final), .match_out(decaps_match)
  );

  // --- Encaps (M4-ENCAPS-ORCH-001) ---
  logic encaps_start, encaps_done;
  logic [8*800-1:0] encaps_ek_buf;
  logic [255:0] encaps_m_buf;
  logic [255:0] encaps_K;
  logic [8*768-1:0] encaps_c;

  pqc_mlkem_encaps_top #(.COEFF_W(COEFF_W), .K(2)) encaps (
    .clk(clk), .reset(rst), .start(encaps_start),
    .ek_in(encaps_ek_buf), .m_in(encaps_m_buf),
    .done(encaps_done), .K_out(encaps_K), .c_out(encaps_c)
  );

  // --- KeyGen-orkestraattori ---
  logic keygen_start, keygen_done;
  logic [255:0] d_seed_buf, z_seed_buf;
  logic [8*800-1:0] ek_out;
  logic [8*1632-1:0] dk_out;
  logic [255:0] dbg_rho, dbg_sigma;
  logic [256*COEFF_W-1:0] dbg_A00;
  logic [4:0] dbg_state;

  pqc_mlkem_keygen_core #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW)) keygen (
    .clk(clk), .reset(rst), .start(keygen_start),
    .d_seed(d_seed_buf), .z_seed(z_seed_buf),
    .done(keygen_done), .ek_out(ek_out), .dk_out(dk_out),
    .debug_rho(dbg_rho), .debug_sigma(dbg_sigma), .debug_A00(dbg_A00), .debug_state(dbg_state)
  );

  // --- Kiinteat tunnistehashit KeyGen-tapahtumille (audit-loki) ---
  // SHA3-256("KEYGEN_STARTED_EVENT"/"KEYGEN_COMPLETED_EVENT"),
  // pack_bytes-konvention mukaisesti - EI kryptografista avain-
  // materiaalia lokiin, vain KIINTEA, ennalta tunnettu tapahtuma-
  // merkki.
  localparam logic [255:0] KEYGEN_STARTED_HASH =
    256'h5b5f32e23f0b447c0b872006ed81734ec8c305d1bc71f261d07193f31c23b68;
  localparam logic [255:0] KEYGEN_COMPLETED_HASH =
    256'hb634916025159880127a357fd392702fdeab5c38a97e47f846aa588e6617953;
  // M4-TAU-001 watchdog-integraatio: kiintea tunnistehash sille
  // erikoistapaukselle etta watchdog keskeyttaa suorituksen KESKEN
  // KeyGenin oman kaynnin - TAMA lokitetaan AINA, riippumatta ECU:n
  // omasta tilasta (TN-002:n oma vaatimus: vika lokitetaan vaikka
  // kayttoyksikko on vaarantunut).
  localparam logic [255:0] KEYGEN_WATCHDOG_INTERRUPTED_HASH =
    256'h7d07634cc39e92beabe29262bd672fd15156917f4cfb96b60531dfe36d9e476;

  // M4-DECAPS-ORCH-001 Wishbone-integraatio: samat kolme tapahtuma-
  // tyyppia myos Decapsille, samalla periaatteella.
  localparam logic [255:0] DECAPS_STARTED_HASH =
    256'h17a30f6b265de08941701b60853803f3765366e6813c8ff7049c65d0f7443a5;
  localparam logic [255:0] DECAPS_COMPLETED_HASH =
    256'hc8e62f26f38dfe54ea7377f2d1f9e095416dab0e7283e492f31549c78b3563c8;
  localparam logic [255:0] DECAPS_WATCHDOG_INTERRUPTED_HASH =
    256'h0f3634643e79382fd48f5100fcaaa5c9dda010e2756a9a4729240cd3a7cd5152;

  logic keygen_busy;
  logic decaps_busy;
  logic encaps_busy;
  logic pending_audit_valid;
  logic [255:0] pending_audit_hash;

  always_ff @(posedge clk) begin
    if (rst) begin
      keygen_busy <= 1'b0;
      decaps_busy <= 1'b0;
      encaps_busy <= 1'b0;
    end else begin
      if (keygen_start) keygen_busy <= 1'b1;
      if (keygen_done) keygen_busy <= 1'b0;
      if (decaps_start) decaps_busy <= 1'b1;
      if (decaps_done) decaps_busy <= 1'b0;
      if (encaps_start) encaps_busy <= 1'b1;
      if (encaps_done) encaps_busy <= 1'b0;
      // Watchdog-keskeytys KESKEN KeyGenin TAI Decapsin oman ajon -
      // pysayta myos ajon oma tila (ECU ei voi enaa luottaa
      // keskeneraiseen tulokseen)
      if (wd_timeout_event && keygen_busy) keygen_busy <= 1'b0;
      if (wd_timeout_event && decaps_busy) decaps_busy <= 1'b0;
    end
  end

  // --- Audit-kirjoitusarbitrointi: watchdog-keskeytys (KeyGen tai
  // Decaps) > KeyGen-omat tapahtumat > Decaps-omat tapahtumat -
  // sama periaate kuin pqc_tau_core.sv:ssa (M4-TAU-001 Osa 4). ---
  logic keygen_event_pending;
  logic [255:0] keygen_event_hash;
  logic pending_watchdog_interrupt;
  logic pending_watchdog_interrupt_decaps;
  logic decaps_event_pending;
  logic [255:0] decaps_event_hash;
  always_ff @(posedge clk) begin
    if (rst) begin
      keygen_event_pending <= 1'b0;
      pending_watchdog_interrupt <= 1'b0;
      pending_watchdog_interrupt_decaps <= 1'b0;
      decaps_event_pending <= 1'b0;
    end else begin
      if (wd_timeout_event && keygen_busy) begin
        pending_watchdog_interrupt <= 1'b1;
      end else if (audit_write_valid && !audit_write_busy && pending_watchdog_interrupt) begin
        pending_watchdog_interrupt <= 1'b0;
      end

      if (wd_timeout_event && decaps_busy) begin
        pending_watchdog_interrupt_decaps <= 1'b1;
      end else if (audit_write_valid && !audit_write_busy && !pending_watchdog_interrupt &&
                    pending_watchdog_interrupt_decaps) begin
        pending_watchdog_interrupt_decaps <= 1'b0;
      end

      if (keygen_start) begin
        keygen_event_pending <= 1'b1;
        keygen_event_hash <= KEYGEN_STARTED_HASH;
      end else if (keygen_done) begin
        keygen_event_pending <= 1'b1;
        keygen_event_hash <= KEYGEN_COMPLETED_HASH;
      end else if (audit_write_valid && !audit_write_busy && !pending_watchdog_interrupt &&
                    !pending_watchdog_interrupt_decaps) begin
        keygen_event_pending <= 1'b0;
      end

      if (decaps_start) begin
        decaps_event_pending <= 1'b1;
        decaps_event_hash <= DECAPS_STARTED_HASH;
      end else if (decaps_done) begin
        decaps_event_pending <= 1'b1;
        decaps_event_hash <= DECAPS_COMPLETED_HASH;
      end else if (audit_write_valid && !audit_write_busy && !pending_watchdog_interrupt &&
                    !pending_watchdog_interrupt_decaps && !keygen_event_pending) begin
        decaps_event_pending <= 1'b0;
      end
    end
  end

  assign audit_write_valid = pending_watchdog_interrupt || pending_watchdog_interrupt_decaps ||
                              keygen_event_pending || decaps_event_pending;
  assign audit_decision_hash_buf =
    pending_watchdog_interrupt ? KEYGEN_WATCHDOG_INTERRUPTED_HASH :
    pending_watchdog_interrupt_decaps ? DECAPS_WATCHDOG_INTERRUPTED_HASH :
    keygen_event_pending ? keygen_event_hash : decaps_event_hash;

  // --- Osoitedekoodaus ---
  wire is_data_range   = (wb_adr_i < 11'h100);
  wire is_ctrl_range   = (wb_adr_i >= 11'h100) && (wb_adr_i <= 11'h107);
  wire is_audit_range  = (wb_adr_i >= 11'h110) && (wb_adr_i <= 11'h119);
  wire is_keygen_range = (wb_adr_i >= 11'h120) && (wb_adr_i <= 11'h129);
  wire is_decaps_range = (wb_adr_i >= 11'h130) && (wb_adr_i <= 11'h139);
  wire is_encaps_range = (wb_adr_i >= 11'h140) && (wb_adr_i <= 11'h149);

  logic [10:0] word_sel;
  logic keygen_done_sticky;
  logic decaps_done_sticky;
  logic encaps_done_sticky;

  always_ff @(posedge clk) begin
    ctrl_start_pulse <= 1'b0;
    load_valid <= 1'b0;
    keygen_start <= 1'b0;
    decaps_start <= 1'b0;
    encaps_start <= 1'b0;
    heartbeat_valid <= 1'b0;
    wd_config_valid <= 1'b0;

    if (rst) begin
      ctrl_mode <= 1'b0; ctrl_count <= 8'd0; ctrl_pair_dist <= 8'd0;
      ctrl_base_addr0 <= '0; ctrl_base_addr1 <= '0;
      ctrl_zeta0 <= '0; ctrl_zeta1 <= '0;
      word_sel <= 11'd0;
      d_seed_buf <= '0; z_seed_buf <= '0;
      keygen_done_sticky <= 1'b0;
      decaps_done_sticky <= 1'b0;
      encaps_done_sticky <= 1'b0;
      wd_timeout_cycles <= 32'd100000;
    end else begin
      if (keygen_done) keygen_done_sticky <= 1'b1;
      if (decaps_done) decaps_done_sticky <= 1'b1;
      if (encaps_done) encaps_done_sticky <= 1'b1;

      if (wb_cyc_i && wb_stb_i && wb_we_i) begin
        if (is_data_range) begin
          load_valid <= 1'b1;
          load_addr  <= wb_adr_i[7:0];
          load_data  <= wb_dat_i;
        end else if (is_ctrl_range) begin
          case (wb_adr_i[3:0])
            4'h0: begin ctrl_start_pulse <= wb_dat_i[0]; ctrl_mode <= wb_dat_i[1]; end
            4'h1: ctrl_count      <= wb_dat_i[7:0];
            4'h2: ctrl_pair_dist  <= wb_dat_i[7:0];
            4'h3: ctrl_base_addr0 <= wb_dat_i[SPAD_AW-1:0];
            4'h4: ctrl_base_addr1 <= wb_dat_i[SPAD_AW-1:0];
            4'h5: ctrl_zeta0      <= wb_dat_i;
            4'h6: ctrl_zeta1      <= wb_dat_i;
            default: ;
          endcase
        end else if (is_audit_range) begin
          case (wb_adr_i[7:0])
            8'h10: word_sel <= wb_dat_i[10:0];  // AUDIT_WORD_SEL (jaettu word_sel-rekisteri)
            8'h16: audit_read_seq <= wb_dat_i[7:0];
            default: ;
          endcase
        end else if (is_keygen_range) begin
          case (wb_adr_i[7:0])
            8'h20: word_sel <= wb_dat_i[10:0];
            8'h21: if (word_sel < 16) d_seed_buf[word_sel*16 +: 16] <= wb_dat_i;
            8'h22: if (word_sel < 16) z_seed_buf[word_sel*16 +: 16] <= wb_dat_i;
            8'h23: begin keygen_start <= 1'b1; keygen_done_sticky <= 1'b0; end
            8'h27: heartbeat_valid <= 1'b1;  // HEARTBEAT
            8'h28: begin wd_timeout_cycles <= {16'b0, wb_dat_i}; wd_config_valid <= 1'b1; end  // WATCHDOG_TIMEOUT_CONFIG
            default: ;
          endcase
        end else if (is_decaps_range) begin
          case (wb_adr_i[7:0])
            8'h30: word_sel <= wb_dat_i[10:0];  // DECAPS_WORD_SEL
            8'h31: if (word_sel < 384) decaps_c_buf[word_sel*16 +: 16] <= wb_dat_i;   // DECAPS_C_IN
            8'h32: if (word_sel < 816) decaps_dk_buf[word_sel*16 +: 16] <= wb_dat_i;  // DECAPS_DK_IN
            8'h33: begin decaps_start <= 1'b1; decaps_done_sticky <= 1'b0; end        // DECAPS_START
            default: ;
          endcase
        end else if (is_encaps_range) begin
          case (wb_adr_i[7:0])
            8'h40: word_sel <= wb_dat_i[10:0];  // ENCAPS_WORD_SEL
            8'h41: if (word_sel < 400) encaps_ek_buf[word_sel*16 +: 16] <= wb_dat_i;  // ENCAPS_EK_IN
            8'h42: if (word_sel < 16) encaps_m_buf[word_sel*16 +: 16] <= wb_dat_i;    // ENCAPS_M_IN
            8'h43: begin encaps_start <= 1'b1; encaps_done_sticky <= 1'b0; end        // ENCAPS_START
            default: ;
          endcase
        end
      end
    end
  end

  // --- Luku ---
  assign read_en   = wb_cyc_i && wb_stb_i && !wb_we_i && is_data_range;
  assign read_addr = wb_adr_i[7:0];

  logic [COEFF_W-1:0] ctrl_read_data, audit_read_data, keygen_read_data, decaps_read_data, encaps_read_data;
  logic ctrl_read_valid, audit_read_valid_reg, keygen_read_valid_reg, decaps_read_valid_reg, encaps_read_valid_reg;

  always_ff @(posedge clk) begin
    if (rst) ctrl_read_valid <= 1'b0;
    else ctrl_read_valid <= wb_cyc_i && wb_stb_i && !wb_we_i && is_ctrl_range;
    if (wb_adr_i[3:0] == 4'h7) ctrl_read_data <= {14'b0, bank_conflict_detected, stage_done};
  end

  always_ff @(posedge clk) begin
    if (rst) audit_read_valid_reg <= 1'b0;
    else audit_read_valid_reg <= wb_cyc_i && wb_stb_i && !wb_we_i && is_audit_range;
    case (wb_adr_i[7:0])
      8'h13: audit_read_data <= {14'b0, audit_log_full, audit_write_done};
      8'h14: audit_read_data <= {8'b0, audit_write_seq};
      8'h15: audit_read_data <= audit_write_chain_hash[word_sel[3:0]*16 +: 16];
      8'h17: audit_read_data <= {15'b0, audit_read_entry_valid};
      8'h18: audit_read_data <= audit_read_chain_hash[word_sel[3:0]*16 +: 16];
      8'h19: audit_read_data <= audit_read_decision_hash[word_sel[3:0]*16 +: 16];
      default: audit_read_data <= '0;
    endcase
  end

  always_ff @(posedge clk) begin
    if (rst) keygen_read_valid_reg <= 1'b0;
    else keygen_read_valid_reg <= wb_cyc_i && wb_stb_i && !wb_we_i && is_keygen_range;
    case (wb_adr_i[7:0])
      8'h24: keygen_read_data <= {14'b0, keygen_done_sticky, keygen_busy};
      8'h25: keygen_read_data <= (word_sel < 400) ? ek_out[word_sel*16 +: 16] : 16'd0;
      8'h26: keygen_read_data <= (word_sel < 816) ? dk_out[word_sel*16 +: 16] : 16'd0;
      8'h29: keygen_read_data <= {14'b0, pending_watchdog_interrupt, ecu_alive};  // WATCHDOG_STATUS
      default: keygen_read_data <= '0;
    endcase
  end

  always_ff @(posedge clk) begin
    if (rst) decaps_read_valid_reg <= 1'b0;
    else decaps_read_valid_reg <= wb_cyc_i && wb_stb_i && !wb_we_i && is_decaps_range;
    case (wb_adr_i[7:0])
      8'h34: decaps_read_data <= {14'b0, decaps_done_sticky, decaps_busy};       // DECAPS_STATUS
      8'h35: decaps_read_data <= (word_sel < 16) ? decaps_K_final[word_sel*16 +: 16] : 16'd0;  // DECAPS_K_FINAL_OUT
      8'h36: decaps_read_data <= {15'b0, decaps_match};                          // DECAPS_MATCH
      default: decaps_read_data <= '0;
    endcase
  end

  always_ff @(posedge clk) begin
    if (rst) encaps_read_valid_reg <= 1'b0;
    else encaps_read_valid_reg <= wb_cyc_i && wb_stb_i && !wb_we_i && is_encaps_range;
    case (wb_adr_i[7:0])
      8'h44: encaps_read_data <= {14'b0, encaps_done_sticky, encaps_busy};       // ENCAPS_STATUS
      8'h45: encaps_read_data <= (word_sel < 16) ? encaps_K[word_sel*16 +: 16] : 16'd0;    // ENCAPS_K_OUT
      8'h46: encaps_read_data <= (word_sel < 384) ? encaps_c[word_sel*16 +: 16] : 16'd0;   // ENCAPS_C_OUT
      default: encaps_read_data <= '0;
    endcase
  end

  always_comb begin
    if (is_data_range) begin
      wb_dat_o = read_data;
      wb_ack_o = read_valid || (wb_cyc_i && wb_stb_i && wb_we_i && is_data_range);
    end else if (is_ctrl_range) begin
      wb_dat_o = ctrl_read_data;
      wb_ack_o = ctrl_read_valid || (wb_cyc_i && wb_stb_i && wb_we_i && is_ctrl_range);
    end else if (is_audit_range) begin
      wb_dat_o = audit_read_data;
      wb_ack_o = audit_read_valid_reg || (wb_cyc_i && wb_stb_i && wb_we_i && is_audit_range);
    end else begin
      wb_dat_o = keygen_read_data;
      wb_ack_o = keygen_read_valid_reg || (wb_cyc_i && wb_stb_i && wb_we_i && is_keygen_range);
    end
    if (is_decaps_range) begin
      wb_dat_o = decaps_read_data;
      wb_ack_o = decaps_read_valid_reg || (wb_cyc_i && wb_stb_i && wb_we_i && is_decaps_range);
    end
    if (is_encaps_range) begin
      wb_dat_o = encaps_read_data;
      wb_ack_o = encaps_read_valid_reg || (wb_cyc_i && wb_stb_i && wb_we_i && is_encaps_range);
    end
  end

endmodule
