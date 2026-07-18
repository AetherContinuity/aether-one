// pqc_dilithium_pack_s.sv
//
// M5-DILITHIUM-001 DK4: bit_pack_s (ETA=4) yhdelle polynomille.
// dilithium-py:n oma kaava: altered = (ETA - c) mod Q, c on raaka
// etumerkillinen (-4..4) arvo. Koska c=ETA-nibble (kayttopaikan oma
// generointikaava rej_bounded_poly:sta), altered=(ETA-(ETA-nibble))
// =nibble - taten altered PALAUTTAA SUORAAN alkuperaisen naytteen-
// oton nelijaksen [0,8].
//
// Pakkaus: 2 kerrointa/tavu (kerroin i BITEISSA [i*4:(i+1)*4) -
// kerroin 0 alempaan nelijakseen, kerroin 1 ylempaan, jne, TAYSIN
// sama konventio kuin rej_bounded_poly.sv:n oma PURKU, nyt kaannettyna).

`timescale 1ns/1ps

module pqc_dilithium_pack_s #(
    parameter int ETA = 4
)(
    input  logic [256*8-1:0] coeffs_in_flat,  // 256 * 8-bittinen etumerkillinen (-4..4)
    output logic [8*128-1:0] packed_out        // 128 tavua (256*4/8) ETA=4:lle
);

  genvar gi;
  generate
    for (gi = 0; gi < 128; gi++) begin : g_byte
      wire signed [7:0] c_lo = coeffs_in_flat[(gi*2)*8 +: 8];
      wire signed [7:0] c_hi = coeffs_in_flat[(gi*2+1)*8 +: 8];
      wire [3:0] altered_lo = ETA[3:0] - c_lo[3:0];
      wire [3:0] altered_hi = ETA[3:0] - c_hi[3:0];
      assign packed_out[gi*8 +: 8] = {altered_hi, altered_lo};
    end
  endgenerate

endmodule
