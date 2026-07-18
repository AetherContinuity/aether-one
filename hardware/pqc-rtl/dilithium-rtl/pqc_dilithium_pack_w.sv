// pqc_dilithium_pack_w.sv
//
// M5-DILITHIUM-001 DK5: bit_pack_w koko w'-vektorille (K=6
// polynomia), GAMMA2=261888 (ML-DSA-65). dilithium-py:n oma kaava:
// TAYSIN SUORA 4-bittinen tiukka pakkaus (EI etumerkkimuunnosta,
// koska w'=UseHint():n tulos ON JO [0,16)-alueella).

`timescale 1ns/1ps

module pqc_dilithium_pack_w #(
    parameter int K = 6
)(
    input  logic [K*256*4-1:0] w_prime_in_flat,  // 4 bittia/kerroin, jo [0,16)-alueella
    output logic [8*K*128-1:0] w_prime_packed_out  // K*128 tavua
);

  // TAYSIN SUORA yhdistaminen - w_prime_in_flat ON JO tasmalleen
  // samassa formaatissa kuin bit_pack_w:n oma tuotos (4 bittia/
  // kerroin, tiukasti pakattu) - EI tarvita muuta logiikkaa.
  assign w_prime_packed_out = w_prime_in_flat;

endmodule
