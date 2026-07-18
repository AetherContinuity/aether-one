// pqc_dilithium_pack_ek.sv
//
// M5-DILITHIUM-001 DK4: ek-pakkaus (FIPS 204: pk = rho || bit_pack_t1(t1)).
//
// dilithium-py:n oma __bit_pack: "r=0; for c in reversed(coeffs):
// r=(r<<n_bits)|c" - taten kerroin i sijoittuu bittiasemaan
// [i*n_bits:(i+1)*n_bits) TIUKASTI PAKATTUNA, EI mitaan uudelleen-
// jarjestelya. Taman ANSIOSTA t1_out_flat (Power2Round-vektorin
// oma ulostulo, jo 256*10-bittisena tiukasti pakattuna per
// polynomi) VASTAA SUORAAN bit_pack_t1:n omaa formaattia - ek-
// pakkaus on siis PELKKA rho:n ja t1:n YHDISTAMINEN, ei mitaan
// uudelleenjarjestelya tai -laskentaa.

`timescale 1ns/1ps

module pqc_dilithium_pack_ek #(
    parameter int K = 6
)(
    input  logic [255:0] rho_in,               // 32 tavua
    input  logic [K*256*10-1:0] t1_in_flat,    // K*320 tavua (10 bittia/kerroin, tiukasti pakattu)
    output logic [8*(32+K*320)-1:0] ek_out      // 32+K*320 tavua (=1952 K=6:lle)
);

  assign ek_out = {t1_in_flat, rho_in};  // rho ENSIN (alimmat tavut), sitten t1 (pack_bytes-konventio: byte0=LSB)

endmodule
