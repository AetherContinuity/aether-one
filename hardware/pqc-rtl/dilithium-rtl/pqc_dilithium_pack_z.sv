// pqc_dilithium_pack_z.sv
//
// M5-DILITHIUM-001 DK6 S8: bit_pack_z, yksi polynomi, GAMMA1=2^19
// (ML-DSA-65). dilithium-py:n oma kaava: altered=GAMMA1-z, sitten
// tiukka 20-bittinen pakkaus.
//
// TAMA ON SAMA KAAVA kuin jo todistetussa pqc_dilithium_unpack_z.sv:ssa
// (altered=GAMMA1-z <=> z=GAMMA1-altered - sama laskutoimitus toimii
// molempiin suuntiin, koska kaava on oma kaannospuolensa). Kaksinkertaisen
// komplementin trikki (todistettu aiemmin pack_s/pack_t0/unpack_z:ssa)
// toimii jalleen suoraan.

`timescale 1ns/1ps

module pqc_dilithium_pack_z #(
    parameter int GAMMA1 = 524288,
    parameter int ZW = 24
)(
    input  logic [256*ZW-1:0] z_in_flat,     // 256 * ZW-bittinen etumerkillinen z-arvo
    output logic [256*20-1:0] packed_out      // 256 * 20-bittinen tiukka pakkaus (altered-arvot)
);

  genvar gi;
  generate
    for (gi = 0; gi < 256; gi++) begin : g_coeff
      wire signed [ZW-1:0] z_val = z_in_flat[gi*ZW +: ZW];
      wire [19:0] altered = GAMMA1[19:0] - z_val[19:0];
      assign packed_out[gi*20 +: 20] = altered;
    end
  endgenerate

endmodule
