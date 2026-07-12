// pqc_byteencode_d1.sv
//
// M3 Issue #7, Vaihtoehto A (ks. M3_BYTEENCODE_DESIGN_NOTE.md):
// ByteEncode1/ByteDecode1, d=1 KAANNOSAIKAISENA (ei runtime-porttina).
//
// KRIITTINEN, LOPULLISESTI TODISTETTU LOYDOS (2026-07-12): Icarus
// Verilog EI valita unpacked-taulukkoa (esim. "logic x [0:255]")
// oikein moduulin PORTIN lapi - taysin eristetty minimitesti (8
// alkion kopiointi, assign/always_comb/generate, kaikki tavat
// testattu) osoitti etta vastaanottava puoli saa aina 'x':n
// riippumatta leveydesta (testattu seka 1-bittisella etta
// 16-bittisella elementilla). Sisaisesti (ilman porttia, samassa
// scopessa TAI hierarkkisen pistoksen kautla kuten dut.bank0[i]=...
// M2:ssa) unpacked-taulukko toimii TAYDELLISESTI - ongelma on
// SPESIFISESTI porttiyhteydessa.
//
// Tama selittaa TAYDELLISESTI kaikki taman session ByteEncode/Decode-
// epaonnistumiset (kayttivat unpacked-taulukkoa porttina) ja miksi
// mikaan M2:n moduuli ei koskaan tormannyt tahan (kayttivat joko
// yksittaisia leveita arvoja portteina TAI hierarkkista pistoa
// taulukoihin, ei koskaan unpacked-taulukkoa suoraan porttina).
//
// KORJAUS: portit ovat PAKATTUJA vektoreita (logic [N-1:0]), ei
// unpacked-taulukoita. 256 bittia f_in:na yhtena 256-bittisena
// bussina, viipaloituna [i +: 1] tai [i*8 +: 8] tarpeen mukaan.
// Todistettu toimivaksi eristetylla testilla ennen tata tiedostoa.

`timescale 1ns/1ps

module pqc_byteencode_d1 (
    input  logic [255:0] f_in,      // 256 bittia (Z_1-arvot), pakattuna
    output logic [255:0] b_out      // 32 tavua = 256 bittia, pakattuna
);

  // d=1: ByteEncode1(F) = BitsToBytes(F). F[i] menee suoraan bittiin i
  // (ei tarvita digit-splittausta koska d=1). BitsToBytes:n oma
  // maaritelma (Algoritmi 3): B[floor(i/8)] += b[i] * 2^(i mod 8) -
  // taalla b=F suoraan, joten B on vain F:n bitit uudelleenjarjestettyna
  // tavuittain - itse asiassa sama bittijarjestys, koska F ja B ovat
  // molemmat vain 256-bittisia lineaarisia sarjoja samassa jarjestyksessa.
  assign b_out = f_in;

endmodule


module pqc_bytedecode_d1 (
    input  logic [255:0] b_in,
    output logic [255:0] f_out
);

  // d=1: ByteDecode1 on ByteEncode1:n kaanteisoperaatio - sama
  // suora bittikopiointi (mod 2 on triviaali koska data on jo 1 bitti).
  assign f_out = b_in;

endmodule
