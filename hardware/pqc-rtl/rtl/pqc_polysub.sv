// pqc_polysub.sv
//
// M3 Issue #8, Vaihe 4: koordinaatittainen mod-q-vahennys kahdelle
// 256-kertoimiselle polynomille (K-PKE.Decrypt rivi 6: w = v' - inner).
// Sama rakenne kuin pqc_polyadd.sv.

`timescale 1ns/1ps

module pqc_polysub #(
    parameter int COEFF_W = 16,
    parameter int Q       = 3329
)(
    input  logic [256*COEFF_W-1:0] a_in,
    input  logic [256*COEFF_W-1:0] b_in,
    output logic [256*COEFF_W-1:0] diff_out
);

  always_comb begin
    for (int i = 0; i < 256; i++) begin
      logic signed [COEFF_W:0] a_val, b_val, d;
      a_val = {1'b0, a_in[i*COEFF_W +: COEFF_W]};
      b_val = {1'b0, b_in[i*COEFF_W +: COEFF_W]};
      d = a_val - b_val;
      if (d < 0) d = d + Q;
      diff_out[i*COEFF_W +: COEFF_W] = d[COEFF_W-1:0];
    end
  end

endmodule
