// pqc_multiplyntts.sv
//
// M3 Issue #8 (esityo): MultiplyNTTs, FIPS 203 Algoritmi 11. Pistetulo
// NTT-alueessa, 128 BaseCaseMultiply-kutsua, kukin omalla gamma-arvollaan
// (gamma_i = zeta^(2*BitRev7(i)+1) mod q, i=0..127 - FIPS 203 Appendix A,
// toinen taulukko).
//
// Uudelleenkayttaa jo todennetun pqc_basecasemul-moduulin (M3 Issue #1)
// suoraan, 128 genvar-generoitua instanssia - EI uutta aritmetiikkaa,
// vain kokoonpano.
//
// Portit PAKATTUINA vektoreina (ks. M3_BYTEENCODE_DESIGN_NOTE.md §7 -
// unpacked-taulukko ei toimi porttina tassa iverilog-versiossa,
// taydellisesti todistettu Issue #7:ssa).

`timescale 1ns/1ps

module pqc_multiplyntts #(
    parameter int COEFF_W = 16,
    parameter int Q       = 3329
)(
    input  logic [256*COEFF_W-1:0] f_hat,
    input  logic [256*COEFF_W-1:0] g_hat,
    output logic [256*COEFF_W-1:0] h_hat
);

  logic [COEFF_W-1:0] gamma_rom [0:127];
  initial $readmemh("m2-golden/multiplyntts_gamma_rom.memh", gamma_rom);

  genvar i;
  generate
    for (i = 0; i < 128; i = i + 1) begin : bcm_loop
      pqc_basecasemul #(.COEFF_W(COEFF_W), .Q(Q)) bcm (
        .a0(f_hat[(2*i)*COEFF_W +: COEFF_W]),
        .a1(f_hat[(2*i+1)*COEFF_W +: COEFF_W]),
        .b0(g_hat[(2*i)*COEFF_W +: COEFF_W]),
        .b1(g_hat[(2*i+1)*COEFF_W +: COEFF_W]),
        .gamma(gamma_rom[i]),
        .c0(h_hat[(2*i)*COEFF_W +: COEFF_W]),
        .c1(h_hat[(2*i+1)*COEFF_W +: COEFF_W])
      );
    end
  endgenerate

endmodule
