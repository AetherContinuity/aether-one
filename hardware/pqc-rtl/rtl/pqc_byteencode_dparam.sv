// pqc_byteencode_dparam.sv
//
// M3 Issue #7 (jatko-osa, d=4,5,10,11,12 - d=1 valmis erikseen
// pqc_byteencode_d1.sv:ssa): ByteEncode_d/ByteDecode_d, D
// KAANNOSAIKAISENA parametrina, PAKATTUINA vektoreina portteina
// (ks. M3_BYTEENCODE_DESIGN_NOTE.md §7 - unpacked-taulukko ei toimi
// porttina tassa iverilog-versiossa, taydellisesti todistettu).
//
// MATEMAATTINEN OIVALLUS (vahvistettu golden-mallissa ennen tata
// tiedostoa, ks. commit-viesti): ByteEncode/ByteDecode on pelkkaa
// SAMAN LINEAARISEN BITTIJONON uudelleenryhmittelyä - digit-splittaus
// (d bittia per arvo) ja tavupakkaus (8 bittia per tavu) ovat kaksi
// eri tapaa ryhmitella TAYSIN sama 256*d-bittinen jono, ei mitaan
// permutaatiota. Tasta seuraa:
//
// - d<12: suora bittikopiointi (assign) on TAYSIN OIKEA operaatio
//   seka ByteEncodelle etta ByteDecodelle - ei tarvita mitaan
//   laskentaa, vain uudelleentulkinta.
// - d=12: ByteEncode12 on myos suora bittikopiointi (FIPS 203:n oma
//   tyyppikuri: ByteEncode12:n syote on jo mod q). ByteDecode12
//   tarvitsee YHDEN lisavaiheen: kunkin 12-bittisen segmentin oma
//   mod q -reduktio (segmentti voi olla 0..4095, mutta Z_q on 0..3328).

`timescale 1ns/1ps

module pqc_byteencode_dparam #(
    parameter int D = 1  // 1, 4, 5, 10, 11 tai 12
)(
    input  logic [256*D-1:0] f_in,
    output logic [256*D-1:0] b_out
);

  // Kaikilla D:n arvoilla (myos 12): suora bittikopiointi - ks. kommentti ylla.
  assign b_out = f_in;

endmodule


module pqc_bytedecode_dparam #(
    parameter int D = 1,
    parameter int Q = 3329
)(
    input  logic [256*D-1:0] b_in,
    output logic [256*D-1:0] f_out
);

  generate
    if (D == 12) begin : g_mod_q
      // ByteDecode12: jokainen 12-bittinen segmentti reduosoidaan
      // erikseen modulo Q (FIPS 203 Algoritmi 6, d=12-erikoistapaus).
      always_comb begin
        for (int i = 0; i < 256; i++) begin
          logic [11:0] raw_segment;
          raw_segment = b_in[i*12 +: 12];
          f_out[i*12 +: 12] = raw_segment % Q;
        end
      end
    end else begin : g_direct
      // d<12: suora bittikopiointi, ks. moduulin oma paakommentti.
      assign f_out = b_in;
    end
  endgenerate

endmodule
