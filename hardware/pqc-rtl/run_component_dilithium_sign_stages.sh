#!/bin/bash
# COMPONENT-tason testit: kokonainen Sign-vaihe (S1,S2,S4,S8).
# Taso: Component (ks. TESTING.md). Ajetaan joka pushilla.
# HUOM: kayttaa MINIMAALISIA tiedostolistoja per testi (EI yhteista
# dilithium_common_files.sh:n koko listaa), koska se sisaltaa raskaita
# moduuleja (sign_hint_core) jotka hidastaisivat elaboraatiota
# tarpeettomasti nailla kevyilla testeilla.
set -euo pipefail
cd "$(dirname "$0")"

SHAKE_FILES="rtl/pqc_keccak_pad.sv rtl/pqc_keccak_absorb.sv rtl/pqc_keccak_squeeze.sv rtl/pqc_keccak_f1600.sv rtl/pqc_shake256.sv rtl/pqc_shake128.sv"

run_test() {
  local name="$1"
  shift
  echo "--- $name ---"
  iverilog -g2012 -o "sim/component_$name" "$@"
  vvp "sim/component_$name"
}

run_test "S1_expand_mask_poly" $SHAKE_FILES \
  dilithium-rtl/pqc_dilithium_unpack_z.sv dilithium-rtl/pqc_dilithium_expand_mask_poly.sv \
  dilithium-rtl/pqc_dilithium_expand_mask_poly_tb.sv

run_test "S2_expand_mask_vector" $SHAKE_FILES \
  dilithium-rtl/pqc_dilithium_unpack_z.sv dilithium-rtl/pqc_dilithium_expand_mask_poly.sv \
  dilithium-rtl/pqc_dilithium_expand_mask_vector.sv dilithium-rtl/pqc_dilithium_expand_mask_vector_tb.sv

run_test "S4_sign_challenge" $SHAKE_FILES \
  dilithium-rtl/pqc_dilithium_decompose.sv dilithium-rtl/pqc_dilithium_pack_w.sv \
  dilithium-rtl/pqc_dilithium_sample_in_ball.sv dilithium-rtl/pqc_dilithium_sign_challenge.sv \
  dilithium-rtl/pqc_dilithium_sign_challenge_tb.sv

run_test "S8_pack_z_vector" dilithium-rtl/pqc_dilithium_pack_z.sv \
  dilithium-rtl/pqc_dilithium_pack_z_vector.sv dilithium-rtl/pqc_dilithium_pack_z_vector_tb.sv

run_test "S8_pack_sig" dilithium-rtl/pqc_dilithium_pack_z.sv dilithium-rtl/pqc_dilithium_pack_z_vector.sv \
  dilithium-rtl/pqc_dilithium_pack_h.sv dilithium-rtl/pqc_dilithium_pack_sig.sv \
  dilithium-rtl/pqc_dilithium_pack_sig_tb.sv

echo "=================================================="
echo "PASS: kaikki COMPONENT-tason Sign-vaihetestit lapaisivat"
echo "=================================================="
