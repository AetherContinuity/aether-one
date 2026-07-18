// pqc_dilithium_decompose.sv
//
// M5-DILITHIUM-001 DK5: Decompose_alpha (FIPS 204 Algoritmi 36),
// alpha=2*GAMMA2=523776 (ML-DSA-65). Perusta HighBits/LowBits/
// MakeHint/UseHint-funktioille.
//
// dilithium-py:n oma kaava:
//   rp = r mod Q
//   r0 = reduce_mod_pm(rp, alpha)  (etumerkillinen, (-alpha/2,alpha/2])
//   jos (rp-r0) == Q-1: r1=0, r0=r0-1 (ERIKOISTAPAUS)
//   muuten: r1 = (rp-r0)/alpha
//
// alpha=523776 ON KIINTEA VAKIO synteesin aikana - jakolasku
// toteutettu suoraan (synteesityokalut optimoivat kiintean jakajan
// jakolaskun tehokkaasti, esim. kerto-siirto-sarjaksi).

`timescale 1ns/1ps

module pqc_dilithium_decompose #(
    parameter int Q = 8380417,
    parameter int CW = 23,
    parameter int ALPHA = 523776  // 2*GAMMA2
)(
    input  logic [CW-1:0] r_in,          // Zq-edustaja [0,Q)
    output logic [3:0] r1_out,           // [0,16) - m=(Q-1)/ALPHA=16
    output logic signed [CW-1:0] r0_out  // etumerkillinen (-ALPHA/2,ALPHA/2]
);

  logic [CW-1:0] rp;
  logic [19:0] r0_mod;           // rp mod ALPHA, [0,ALPHA) - ALPHA<2^20
  logic signed [20:0] r0_signed;
  logic signed [CW:0] rp_signed;
  logic signed [CW:0] rp_minus_r0_signed;  // TAYSIN etumerkillinen laskenta - valttaa mixed signed/unsigned-sudenkuopan
  logic [3:0] r1_normal;

  assign rp = r_in;  // jo Zq-edustaja
  assign r0_mod = rp % ALPHA;
  assign r0_signed = (r0_mod > (ALPHA/2)) ? ($signed({1'b0, r0_mod}) - ALPHA) : $signed({1'b0, r0_mod});

  // rp - r0 (KOKONAAN etumerkillisena - EI sekoiteta unsigned rp:n kanssa)
  assign rp_signed = $signed({1'b0, rp});
  assign rp_minus_r0_signed = rp_signed - r0_signed;
  assign r1_normal = rp_minus_r0_signed / ALPHA;

  // Erikoistapaus: rp-r0 == Q-1
  wire is_special = (rp_minus_r0_signed == (Q-1));

  assign r1_out = is_special ? 4'd0 : r1_normal;
  assign r0_out = is_special ? (r0_signed - 1) : r0_signed;

endmodule
