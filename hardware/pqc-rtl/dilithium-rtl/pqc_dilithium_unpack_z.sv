// pqc_dilithium_unpack_z.sv
//
// M5-DILITHIUM-001 DK5: bit_unpack_z, yksi polynomi, GAMMA1=2^19
// (ML-DSA-65). dilithium-py:n oma kaava:
//   altered_coeffs = tiukka 20-bittinen purku (kerroin i biteissa
//                    [i*20:(i+1)*20))
//   z[i] = GAMMA1 - altered_coeffs[i]
//
// SAMA "vakio miinus arvo" -kaava kuin bit_pack_t0/bit_pack_s:ssa jo
// todistettu - PACKAUS JA PURKU OVAT SYMMETRISIA taman kaavan
// ansiosta (altered=C-z <=> z=C-altered, sama laskutoimitus
// molempiin suuntiin).

`timescale 1ns/1ps

module pqc_dilithium_unpack_z #(
    parameter int GAMMA1 = 524288,
    parameter int ZW = 24  // z:n oma tallennusleveys (etumerkillinen, riittava GAMMA1:lle)
)(
    input  logic [256*20-1:0] packed_in,   // 256 * 20-bittinen tiukka pakkaus (altered-arvot)
    output logic [256*ZW-1:0] z_out_flat    // 256 * ZW-bittinen etumerkillinen z-arvo
);

  genvar gi;
  generate
    for (gi = 0; gi < 256; gi++) begin : g_coeff
      wire [19:0] altered = packed_in[gi*20 +: 20];
      // GAMMA1-altered: kaksinkertaisen komplementin trikki (todistettu
      // aiemmin pack_s/pack_t0:ssa) - suora vahennyslasku toimii oikein
      // modulaarisen aritmetiikan ansiosta, EI tarvita erillista
      // etumerkinkasittelya.
      wire signed [ZW-1:0] z_val = GAMMA1[ZW-1:0] - {{(ZW-20){1'b0}}, altered};
      assign z_out_flat[gi*ZW +: ZW] = z_val;
    end
  endgenerate

endmodule
