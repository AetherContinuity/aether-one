// pqc_compress.sv
//
// M3 Issue #6: Compress_d / Decompress_d, FIPS 203 kaavat 4.7/4.8.
// d on ajonaikainen portti (arvot 1,4,5,10,11 kaytossa ML-KEM:n eri
// parametrisarjoissa: du/dv vaihtelevat, d=1 viestin (de)koodaukseen).
//
// Compress_d(x)   = floor((x*2^d + q/2) / q) mod 2^d
// Decompress_d(y)  = floor((y*q + 2^(d-1)) / 2^d)
//
// Pyoristys: FIPS 203:n oma round-half-up-maaritelma. Kaava vahvistettu
// m2-golden/compress_golden.py:ssa FIPS 203:n oman dokumentoidun
// ominaisuuden kautta (Compress_d(Decompress_d(y))==y kaikilla y,
// kaikilla d<12) - taydellinen (ei satunnaisotos) tarkistus kaikilla
// d=1..11 ja kaikilla y ajettu ennen taman RTL:n kirjoittamista.
//
// KAYTTAYTYMISMALLI (behavioral), EI synteesikelpoinen RTL - jako
// (/) ei synteesoidu suoraan taksi jaollisena piirina, samoin kuin
// BaseCaseMultiplyn oma "%"-operaattori (ks. pqc_basecasemul.sv).

`timescale 1ns/1ps

module pqc_compress #(
    parameter int COEFF_W = 16,
    parameter int Q       = 3329
)(
    input  logic [3:0]         d,           // 1..11
    input  logic [COEFF_W-1:0] x_in,        // Compress-tulo (Zq)
    output logic [COEFF_W-1:0] compress_out,

    input  logic [COEFF_W-1:0] y_in,        // Decompress-tulo (Z_2^d)
    output logic [COEFF_W-1:0] decompress_out
);

  logic [31:0] two_d;
  logic [31:0] comp_num, comp_div;
  logic [31:0] decomp_num, decomp_div;

  always_comb begin
    two_d = 32'd1 << d;

    // Compress_d(x) = floor((x*2^d + Q/2) / Q) mod 2^d
    comp_num      = x_in * two_d + (Q / 2);
    comp_div      = comp_num / Q;
    compress_out  = comp_div % two_d;

    // Decompress_d(y) = floor((y*Q + 2^(d-1)) / 2^d)
    decomp_num      = y_in * Q + (two_d / 2);
    decompress_out  = decomp_num / two_d;
  end

endmodule
