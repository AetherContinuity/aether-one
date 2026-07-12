// pqc_ntt_level6_2lane.sv
//
// M2 Vaihe 2b: OIKEA Kyber-NTT:n taso 6 (length=128), 2 lanea, 64
// butterflya per lane. Kayttaa SAMAA lane_fsm-moduulia kuin M1/M2 Vaihe 1
// (rtl/pqc_rvv_cluster_2lane.sv), mutta OMANA, erillisena ylatason
// moduulinaan - ei muuteta pqc_rvv_cluster_2lane:a, jottei olemassa
// oleva M1/M2 Vaihe 1 -todennus vaarannu.
//
// KAYTTAYTYMISMALLI (behavioral), EI synteesikelpoinen RTL.
//
// Todistaa: taman moduulin tulos tasmaa Python-golden-mallin
// ntt_level6_only()-funktioon (ks. m2-golden/kyber_ntt_golden.py)
// bittitarkasti, kokonaiselle 256-kertoimiselle polynomille.
//
// SKOOPIN RAJAUS (tietoinen):
// - Yksi 256-sanan muistipankki (ei M1:n tekopankkikonfliktia - tama
//   testaa NTT-matematiikkaa, ei muistiarbitrointia, ks. M2 Vaihe 3).
// - Lane0 kasittelee butterfly-indeksit 0..63 (a=0..63, b=128..191).
// - Lane1 kasittelee butterfly-indeksit 64..127 (a=64..127, b=192..255).
// - PAIR_DIST=128 (lane_fsm:n uusi parametri, oletus muualla on 1).
// - Taso 6:lla on FIPS 203:n oman silmukan mukaan VAIN YKSI zeta koko
//   tasolle (length=128 -> vain yksi ryhma, start=0 ainoa arvo) - siksi
//   tw_window taytetaan samalla arvolla joka indeksissa, ei 128:lla eri
//   arvolla. M2 Vaihe 1:n per-butterfly-indeksointi-infrastruktuuri
//   toimii tassa muuttumattomana, redusoituen vakiozetaksi.
// - Ei useampaa tasoa (M2 Vaihe 2c:n laajuus).

`timescale 1ns/1ps

module pqc_ntt_level6_2lane #(
    parameter int COEFF_W   = 16,
    parameter int SPAD_AW   = 9,   // 256 sanaa = 2^8, +marginaali -> 9 bittia
    parameter int TW_WINDOW = 64   // kummankin lanen oma idx-avaruus 0..63
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [7:0] count,       // 64 (butterflya per lane)

    input  logic tw_in_valid,
    input  logic [$clog2(TW_WINDOW)-1:0] tw_in_idx,
    input  logic [COEFF_W-1:0] tw_in_data,

    output logic cluster_done
);

  // Yksi jaettu 256-sanan pankki (ei moni-pankki-arbitrointia tassa
  // vaiheessa - se on M2 Vaihe 3:n laajuus).
  logic [COEFF_W-1:0] mem [0:255];

  logic [COEFF_W-1:0] tw_window [0:TW_WINDOW-1];
  always_ff @(posedge clk) begin
    if (tw_in_valid) tw_window[tw_in_idx] <= tw_in_data;
  end

  logic [SPAD_AW-1:0] addr_a0, addr_b0, addr_a1, addr_b1;
  logic [COEFF_W-1:0] rdata_a0, rdata_b0, rdata_a1, rdata_b1;
  logic [COEFF_W-1:0] wdata_a0, wdata_b0, wdata_a1, wdata_b1;
  logic req0, req1, is_write0, is_write1;
  logic [2:0] state0_w, state1_w;
  logic done0, done1;
  logic [7:0] idx0, idx1;

  // Ei pankkikonfliktia tassa moduulissa - lane0 ja lane1 kirjoittavat/
  // lukevat ERI osoitealueita (0..63/128..191 vs. 64..127/192..255),
  // joten kumpikin saa "grant"-signaalin aina valittomasti.
  logic grant0, grant1;
  assign grant0 = req0;
  assign grant1 = req1;

  lane_fsm #(
    .COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW)
  ) lane0 (
    .clk(clk), .reset(reset), .start(start),
    .base_addr(9'd0), .stride(8'd1), .count(count), .pair_dist(8'd128), .mode(1'b0),
    .mem_addr_a(addr_a0), .mem_addr_b(addr_b0),
    .mem_rdata_a(rdata_a0), .mem_rdata_b(rdata_b0),
    .mem_wdata_a(wdata_a0), .mem_wdata_b(wdata_b0),
    .zeta_in(tw_window[idx0]),
    .req(req0), .is_write(is_write0), .grant(grant0),
    .state(state0_w), .done(done0), .idx_out(idx0)
  );

  lane_fsm #(
    .COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW)
  ) lane1 (
    .clk(clk), .reset(reset), .start(start),
    .base_addr(9'd64), .stride(8'd1), .count(count), .pair_dist(8'd128), .mode(1'b0),
    .mem_addr_a(addr_a1), .mem_addr_b(addr_b1),
    .mem_rdata_a(rdata_a1), .mem_rdata_b(rdata_b1),
    .mem_wdata_a(wdata_a1), .mem_wdata_b(wdata_b1),
    .zeta_in(tw_window[idx1]),
    .req(req1), .is_write(is_write1), .grant(grant1),
    .state(state1_w), .done(done1), .idx_out(idx1)
  );

  assign rdata_a0 = mem[addr_a0];
  assign rdata_b0 = mem[addr_b0];
  assign rdata_a1 = mem[addr_a1];
  assign rdata_b1 = mem[addr_b1];

  always_ff @(posedge clk) begin
    if (grant0 && is_write0) begin
      mem[addr_a0] <= wdata_a0;
      mem[addr_b0] <= wdata_b0;
    end
    if (grant1 && is_write1) begin
      mem[addr_a1] <= wdata_a1;
      mem[addr_b1] <= wdata_b1;
    end
  end

  assign cluster_done = done0 && done1;

endmodule
