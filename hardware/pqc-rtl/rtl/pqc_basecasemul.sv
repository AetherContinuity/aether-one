// pqc_basecasemul.sv
//
// M3 (Issue #1): BaseCaseMultiply, FIPS 203. Pistetulo NTT-alueessa
// kahden asteen-1-polynomin (a0+a1*X) ja (b0+b1*X) kertolaskuna
// modulo (X^2-gamma):
//   c0 = a0*b0 + a1*b1*gamma  (mod Q)
//   c1 = a0*b1 + a1*b0        (mod Q)
//
// SKOOPIN RAJAUS (tietoinen, ks. myos M1/M2-tason vastaava huomautus):
// tama kayttaa SUORAA modulaarilaskentaa (SystemVerilogin oma %),
// EI Montgomery-reduktiota - sama konventio kuin golden-mallissa
// (m2-golden/kyber_ntt_golden.py:n base_case_multiply, joka myos
// kayttaa suoraa "% Q" -laskentaa plain-domainissa, ei Montgomery-
// domainissa). NTT:n oma butterfly-aritmetiikka (lane_fsm) kayttaa
// Montgomery-reduktiota koska zeta on esiskaalattu vain sielle -
// BaseCaseMultiplyn gamma-arvo TASSA on plain-domain-arvo, sama kuin
// golden-mallissa, joten suora modulo on oikea vastine, ei virhe.
//
// KAYTTAYTYMISMALLI (behavioral), EI synteesikelpoinen RTL - "%"-
// operaattori ei synteesoidu suoraan taksi jaollisena piirina.
// Synteesikelpoinen reduktio (Barrett/Montgomery-domainiin siirto)
// on erillinen, myohempi tyo (M4:n jalkeen, jos/kun tarvitaan).

`timescale 1ns/1ps

module pqc_basecasemul #(
    parameter int COEFF_W = 16,
    parameter int Q       = 3329
)(
    input  logic [COEFF_W-1:0] a0,
    input  logic [COEFF_W-1:0] a1,
    input  logic [COEFF_W-1:0] b0,
    input  logic [COEFF_W-1:0] b1,
    input  logic [COEFF_W-1:0] gamma,
    output logic [COEFF_W-1:0] c0,
    output logic [COEFF_W-1:0] c1
);

  // Tuotteet mahtuvat mukavasti 32-bittiin: max(a,b,gamma) < Q=3329,
  // a1*b1*gamma < 3329^3 ~= 3.7*10^10 EI mahdu 32 bittiin sellaisenaan -
  // mutta a1*b1 < 3329^2 ~= 1.1*10^7 mahtuu, ja senkin jalkeen kertominen
  // gammalla ENNEN modulo-operaatiota vaatisi enemman - siksi reduktio
  // tehdaan kahdessa vaiheessa (a1*b1 mod Q ensin, sitten * gamma mod Q)
  // pysyakseen turvallisesti 32-bittisessa aritmetiikassa koko ajan.
  logic [31:0] a1b1_prod, a1b1_mod, a1b1gamma_prod;
  logic [31:0] a0b0_prod, sum0;
  logic [31:0] a0b1_prod, a1b0_prod, sum1;

  always_comb begin
    a1b1_prod      = a1 * b1;
    a1b1_mod       = a1b1_prod % Q;
    a1b1gamma_prod = a1b1_mod * gamma;

    a0b0_prod = a0 * b0;
    sum0      = (a0b0_prod + a1b1gamma_prod) % Q;

    a0b1_prod = a0 * b1;
    a1b0_prod = a1 * b0;
    sum1      = (a0b1_prod + a1b0_prod) % Q;

    c0 = sum0[COEFF_W-1:0];
    c1 = sum1[COEFF_W-1:0];
  end

endmodule
