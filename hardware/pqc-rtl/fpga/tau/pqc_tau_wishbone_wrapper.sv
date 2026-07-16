// pqc_tau_wishbone_wrapper.sv
//
// M4-TAU-001: laajennettu Wishbone-vaylakaare joka yhdistaa
// pqc_ntt_stage_banked-ytimen (M4-SoC-001) JA uuden TAU-audit-lokin
// (pqc_tau_audit_log.sv) SAMAAN vaylaan. 16-bittinen datavayla -
// 256-bittiset hash-arvot pakataan/puretaan 16:sta perakkaisesta
// 16-bittisesta sanasta (AUDIT_WORD_SEL osoittaa senhetkisen sanan).
//
// OSOITEKARTTA:
//   0x000-0x0FF: NTT-datan luku/kirjoitus (kuten M4-SoC-001:ssa)
//   0x100-0x107: NTT-ohjaus/tila (kuten M4-SoC-001:ssa)
//   0x110: AUDIT_WORD_SEL   (kirjoitus: valitse sana 0-15 seuraaville luku/kirjoituksille)
//   0x111: AUDIT_HASH_IN    (kirjoitus: kirjoita 16-bittinen sana decision_hash-puskuriin[AUDIT_WORD_SEL])
//   0x112: AUDIT_COMMIT     (kirjoitus, mika tahansa arvo: laukaisee audit-lokin kirjoituksen)
//   0x113: AUDIT_STATUS     (luku): [0]=write_busy [1]=write_done (sticky) [2]=log_full
//   0x114: AUDIT_SEQ        (luku): viimeisimman kirjoituksen jarjestysnumero (sticky)
//   0x115: AUDIT_CHAIN_OUT  (luku): viimeisimman kirjoituksen chain_hash, sana AUDIT_WORD_SEL
//   0x116: AUDIT_READ_SEQ   (kirjoitus): aseta luettava jarjestysnumero (deferred reconciliation)
//   0x117: AUDIT_READ_VALID (luku): [0]=onko taman seq:in merkinta olemassa
//   0x118: AUDIT_READ_CHAIN (luku): valitun seq:in chain_hash, sana AUDIT_WORD_SEL
//   0x119: AUDIT_READ_DECISION (luku): valitun seq:in decision_hash, sana AUDIT_WORD_SEL

`timescale 1ns/1ps

module pqc_tau_wishbone_wrapper #(
    parameter int COEFF_W = 16,
    parameter int SPAD_AW = 9,
    parameter int LOG_DEPTH = 64
)(
    input  logic clk,
    input  logic rst,

    input  logic [9:0] wb_adr_i,
    input  logic [COEFF_W-1:0] wb_dat_i,
    output logic [COEFF_W-1:0] wb_dat_o,
    input  logic wb_we_i,
    input  logic wb_stb_i,
    input  logic wb_cyc_i,
    output logic wb_ack_o
);

  // --- NTT-ytimen ohjausrekisterit (kuten M4-SoC-001:ssa) ---
  logic ctrl_start_pulse;
  logic ctrl_mode;
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

  // --- Osoitedekoodaus ---
  wire is_data_range  = (wb_adr_i < 10'h100);
  wire is_ctrl_range  = (wb_adr_i >= 10'h100) && (wb_adr_i <= 10'h107);
  wire is_audit_range = (wb_adr_i >= 10'h110) && (wb_adr_i <= 10'h119);

  logic [3:0] word_sel;
  logic [255:0] chain_out_latched, read_chain_latched, read_decision_latched;
  logic write_done_sticky, log_full_sticky;
  logic [7:0] write_seq_sticky;

  always_ff @(posedge clk) begin
    ctrl_start_pulse <= 1'b0;
    load_valid <= 1'b0;
    audit_write_valid <= 1'b0;

    if (rst) begin
      ctrl_mode <= 1'b0; ctrl_count <= 8'd0; ctrl_pair_dist <= 8'd0;
      ctrl_base_addr0 <= '0; ctrl_base_addr1 <= '0;
      ctrl_zeta0 <= '0; ctrl_zeta1 <= '0;
      word_sel <= 4'd0;
      audit_decision_hash_buf <= '0;
      audit_read_seq <= 8'd0;
      write_done_sticky <= 1'b0;
      log_full_sticky <= 1'b0;
      write_seq_sticky <= 8'd0;
    end else begin
      if (audit_write_done) begin
        write_done_sticky <= 1'b1;
        write_seq_sticky <= audit_write_seq;
        chain_out_latched <= audit_write_chain_hash;
      end
      if (audit_log_full) log_full_sticky <= 1'b1;

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
          if (wb_adr_i[3:0] == 4'h0 && wb_dat_i[0]) begin
            write_done_sticky <= 1'b0;  // uusi NTT-ajo tyhjentaa oman statuksensa
          end
        end else if (is_audit_range) begin
          case (wb_adr_i[7:0])
            8'h10: word_sel <= wb_dat_i[3:0];
            8'h11: audit_decision_hash_buf[word_sel*16 +: 16] <= wb_dat_i;
            8'h12: begin
              audit_write_valid <= 1'b1;
              write_done_sticky <= 1'b0;
            end
            8'h16: audit_read_seq <= wb_dat_i[7:0];
            default: ;
          endcase
        end
      end
    end
  end

  // --- Luku (ydin) ---
  assign read_en   = wb_cyc_i && wb_stb_i && !wb_we_i && is_data_range;
  assign read_addr = wb_adr_i[7:0];

  logic [COEFF_W-1:0] ctrl_read_data;
  logic ctrl_read_valid;
  always_ff @(posedge clk) begin
    if (rst) ctrl_read_valid <= 1'b0;
    else ctrl_read_valid <= wb_cyc_i && wb_stb_i && !wb_we_i && is_ctrl_range;
    if (wb_adr_i[3:0] == 4'h7) begin
      ctrl_read_data <= {14'b0, bank_conflict_detected, stage_done};
    end
  end

  logic [COEFF_W-1:0] audit_read_data;
  logic audit_read_valid_reg;
  always_ff @(posedge clk) begin
    if (rst) audit_read_valid_reg <= 1'b0;
    else audit_read_valid_reg <= wb_cyc_i && wb_stb_i && !wb_we_i && is_audit_range;

    case (wb_adr_i[7:0])
      8'h13: audit_read_data <= {13'b0, log_full_sticky, write_done_sticky, audit_write_busy};
      8'h14: audit_read_data <= {8'b0, write_seq_sticky};
      8'h15: audit_read_data <= chain_out_latched[word_sel*16 +: 16];
      8'h17: audit_read_data <= {15'b0, audit_read_entry_valid};
      8'h18: audit_read_data <= audit_read_chain_hash[word_sel*16 +: 16];
      8'h19: audit_read_data <= audit_read_decision_hash[word_sel*16 +: 16];
      default: audit_read_data <= '0;
    endcase
  end

  always_comb begin
    if (is_data_range) begin
      wb_dat_o = read_data;
      wb_ack_o = read_valid || (wb_cyc_i && wb_stb_i && wb_we_i && is_data_range);
    end else if (is_ctrl_range) begin
      wb_dat_o = ctrl_read_data;
      wb_ack_o = ctrl_read_valid || (wb_cyc_i && wb_stb_i && wb_we_i && is_ctrl_range);
    end else begin
      wb_dat_o = audit_read_data;
      wb_ack_o = audit_read_valid_reg || (wb_cyc_i && wb_stb_i && wb_we_i && is_audit_range);
    end
  end

endmodule
