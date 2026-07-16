// pqc_ntt_wishbone_wrapper.sv
//
// M4-SoC-001 (2026-07-19): ohut Wishbone B4 -tyyppinen vaylakaare
// pqc_ntt_stage_banked-ytimelle. TUTKIMUSPROTOTYYPPI (fpga/-
// hakemistossa) - EI VIELA tuotantoytimeen integroitua.
//
// SUUNNITTELUPERIAATE (sama kuin M4-FPGA-001:n bring-up-portit):
// tama kaare EI MUUTA ydinta lainkaan - se VAIN kytkee jo olemassa
// olevan bring-up-rajapinnan (load_valid/load_addr/load_data,
// read_en/read_addr/read_valid/read_data) ja ohjaussignaalit
// (start/count/pair_dist/mode/base_addr/zeta, stage_done/
// bank_conflict_detected) tavanomaisen Wishbone-protokollan taakse.
//
// OSOITEKARTTA (8-bittinen wb_adr, tavusidottu):
//   0x00-0xFF: kertoimen data (load/read bring-up-portin kautta)
//   0x100: CTRL   [0]=start (kirjoitus laukaisee pulssin), [1]=mode
//   0x101: COUNT
//   0x102: PAIR_DIST
//   0x103: BASE_ADDR_LANE0 (alin tavu, SPAD_AW<=8 oletettu tassa)
//   0x104: BASE_ADDR_LANE1
//   0x105: ZETA_LANE0 (alin tavu)
//   0x106: ZETA_LANE1 (alin tavu)
//   0x107: STATUS (luku): [0]=stage_done, [1]=bank_conflict_detected
//
// Yksinkertaistettu: 16-bittinen data (COEFF_W), 9-bittiset osoitteet
// yms. taman prototyypin yksinkertaisuuden vuoksi sovitettu 8-bittiin
// missa mahdollista - taydellinen, tuotantokelpoinen versio vaatisi
// leveamman datavaylan (esim. 32-bit AXI-Lite) todellista SoC-
// integraatiota varten. Tama on ENSIMMAINEN, minimaalinen koe.

`timescale 1ns/1ps

module pqc_ntt_wishbone_wrapper #(
    parameter int COEFF_W = 16,
    parameter int SPAD_AW = 9
)(
    input  logic clk,
    input  logic rst,  // Wishbone-konventio: aktiivinen ylhaalla

    // --- Wishbone B4 slave-rajapinta ---
    input  logic [8:0] wb_adr_i,
    input  logic [COEFF_W-1:0] wb_dat_i,
    output logic [COEFF_W-1:0] wb_dat_o,
    input  logic wb_we_i,
    input  logic wb_stb_i,
    input  logic wb_cyc_i,
    output logic wb_ack_o
);

  // --- Ohjausrekisterit (Wishbone-kirjoitettavia) ---
  logic ctrl_start_pulse;
  logic ctrl_mode;
  logic [7:0] ctrl_count, ctrl_pair_dist;
  logic [SPAD_AW-1:0] ctrl_base_addr0, ctrl_base_addr1;
  logic [COEFF_W-1:0] ctrl_zeta0, ctrl_zeta1;

  // --- Ytimen omat portit ---
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

  // --- Osoitedekoodaus ---
  wire is_data_range = (wb_adr_i < 9'h100);
  wire is_ctrl_range = (wb_adr_i >= 9'h100) && (wb_adr_i <= 9'h107);

  // --- Kirjoitus (Wishbone -> ydin/rekisterit) ---
  always_ff @(posedge clk) begin
    ctrl_start_pulse <= 1'b0;  // oletuksena aina 0, YKSI sykli pulssi kirjoituksesta
    load_valid <= 1'b0;

    if (rst) begin
      ctrl_mode <= 1'b0; ctrl_count <= 8'd0; ctrl_pair_dist <= 8'd0;
      ctrl_base_addr0 <= '0; ctrl_base_addr1 <= '0;
      ctrl_zeta0 <= '0; ctrl_zeta1 <= '0;
    end else if (wb_cyc_i && wb_stb_i && wb_we_i) begin
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
      end
    end
  end

  // --- Luku (ydin/rekisterit -> Wishbone) ---
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

  always_comb begin
    if (is_data_range) begin
      wb_dat_o = read_data;
      wb_ack_o = read_valid || (wb_cyc_i && wb_stb_i && wb_we_i && is_data_range);
    end else begin
      wb_dat_o = ctrl_read_data;
      wb_ack_o = ctrl_read_valid || (wb_cyc_i && wb_stb_i && wb_we_i && is_ctrl_range);
    end
  end

endmodule
