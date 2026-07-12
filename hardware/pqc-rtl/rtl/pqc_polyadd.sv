// pqc_polyadd.sv
//
// M3 Issue #8, Vaihe 2: koordinaatittainen mod-q-yhteenlasku kahdelle
// 256-kertoimiselle polynomille (Tq- tai Rq-domainissa, sama operaatio
// molemmille - FIPS 203:n oma additiokaava on identtinen kummassakin).
// Tarvitaan k:n MultiplyNTTs-tuloksen summaukseen (K-PKE.Decrypt rivi 6).
//
// Portit pakattuina vektoreina (Issue #7:n korjattu periaate).

`timescale 1ns/1ps

module pqc_polyadd #(
    parameter int COEFF_W = 16,
    parameter int Q       = 3329
)(
    input  logic [256*COEFF_W-1:0] a_in,
    input  logic [256*COEFF_W-1:0] b_in,
    output logic [256*COEFF_W-1:0] sum_out
);

  always_comb begin
    for (int i = 0; i < 256; i++) begin
      logic [COEFF_W:0] a_val, b_val, s;
      a_val = {1'b0, a_in[i*COEFF_W +: COEFF_W]};
      b_val = {1'b0, b_in[i*COEFF_W +: COEFF_W]};
      s = a_val + b_val;
      if (s >= Q) s = s - Q;
      sum_out[i*COEFF_W +: COEFF_W] = s[COEFF_W-1:0];
    end
  end

endmodule
