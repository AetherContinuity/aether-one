// pqc_ntt_final_scale.sv
//
// M3 Issue #8, Vaihe 3 (NTT^-1): FIPS 203 Algoritmi 10, rivi 13 -
// jokainen 256 kertoimesta kerrotaan vakiolla 3303 (= 128^-1 mod q)
// butterfly-silmukan JALKEEN, kertaalleen. Ei kuulu itse butterflyyn
// (ks. NTT_INVERSE_DESIGN_NOTE.md §3) - oma pieni, erillinen vaihe,
// sama rakenne kuin pqc_polyadd.sv.

`timescale 1ns/1ps

module pqc_ntt_final_scale #(
    parameter int COEFF_W = 16,
    parameter int Q       = 3329,
    parameter int N_INV   = 3303  // 128^-1 mod 3329 (FIPS 203:n oma vakio)
)(
    input  logic [256*COEFF_W-1:0] f_in,
    output logic [256*COEFF_W-1:0] f_out
);

  always_comb begin
    for (int i = 0; i < 256; i++) begin
      logic [31:0] prod;
      prod = f_in[i*COEFF_W +: COEFF_W] * N_INV;
      f_out[i*COEFF_W +: COEFF_W] = prod % Q;
    end
  end

endmodule
