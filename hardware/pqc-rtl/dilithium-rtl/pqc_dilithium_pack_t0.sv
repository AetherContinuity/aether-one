// pqc_dilithium_pack_t0.sv
//
// M5-DILITHIUM-001 DK4: bit_pack_t0, yksi polynomi. dilithium-py:n
// oma kaava: altered = (1<<12) - c = 4096 - c, c on t0:n etumerkillinen
// arvo (-4096,4096]. altered on AINA [0,8191] (13-bittinen ei-
// negatiivinen), pakataan TIUKASTI (kerroin i biteissa [i*13:(i+1)*13)) -
// TASMALLEEN sama "flat, tiukka pakkaus" -periaate kuin t1_out_flat:lla
// jo oli - ulostulo VOIDAAN muodostaa suoraan yhdistamalla, kunhan
// jokainen altered-arvo on ensin laskettu.

`timescale 1ns/1ps

module pqc_dilithium_pack_t0 #(
    parameter int CW = 23
)(
    input  logic [256*CW-1:0] t0_in_flat,  // etumerkillinen (-4096,4096], CW-bittisena sailytettyna (sign-extended)
    output logic [256*13-1:0] packed_out    // 256*13 bittia = 416 tavua, tiukasti pakattuna
);

  genvar gi;
  generate
    for (gi = 0; gi < 256; gi++) begin : g_coeff
      wire signed [CW-1:0] c = t0_in_flat[gi*CW +: CW];
      wire [12:0] altered = 13'd4096 - c[12:0];
      assign packed_out[gi*13 +: 13] = altered;
    end
  endgenerate

endmodule
