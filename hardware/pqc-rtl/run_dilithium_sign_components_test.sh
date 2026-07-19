#!/bin/bash
# Nopeat Sign-komponenttitestit (S1,S2,S4,S6-makehint,S8-pakkaus).
# KAYTTAA MINIMAALISIA tiedostolistoja per testi - EI yhteista
# dilithium_common_files.sh:n koko listaa, koska se sisaltaa raskaita
# moduuleja (mm. sign_hint_core, 1536 rinnakkaista instanssia), jotka
# hidastaisivat NAIDEN pienten testien elaboraatiota merkittavasti.
set -euo pipefail
cd "$(dirname "$0")"

SHAKE_FILES="rtl/pqc_keccak_pad.sv rtl/pqc_keccak_absorb.sv rtl/pqc_keccak_squeeze.sv rtl/pqc_keccak_f1600.sv rtl/pqc_shake256.sv rtl/pqc_shake128.sv"

run_test() {
  local name="$1"
  shift
  echo "--- $name ---"
  iverilog -g2012 -o "sim/sign_comp_$name" "$@"
  vvp "sim/sign_comp_$name"
}

run_test "expand_mask_poly" $SHAKE_FILES \
  dilithium-rtl/pqc_dilithium_unpack_z.sv dilithium-rtl/pqc_dilithium_expand_mask_poly.sv \
  dilithium-rtl/pqc_dilithium_expand_mask_poly_tb.sv

run_test "expand_mask_vector" $SHAKE_FILES \
  dilithium-rtl/pqc_dilithium_unpack_z.sv dilithium-rtl/pqc_dilithium_expand_mask_poly.sv \
  dilithium-rtl/pqc_dilithium_expand_mask_vector.sv dilithium-rtl/pqc_dilithium_expand_mask_vector_tb.sv

run_test "sign_challenge" $SHAKE_FILES \
  dilithium-rtl/pqc_dilithium_decompose.sv dilithium-rtl/pqc_dilithium_pack_w.sv \
  dilithium-rtl/pqc_dilithium_sample_in_ball.sv dilithium-rtl/pqc_dilithium_sign_challenge.sv \
  dilithium-rtl/pqc_dilithium_sign_challenge_tb.sv

run_test "make_hint" \
  dilithium-rtl/pqc_dilithium_decompose.sv dilithium-rtl/pqc_dilithium_make_hint.sv \
  dilithium-rtl/pqc_dilithium_make_hint_tb.sv

run_test "pack_z" dilithium-rtl/pqc_dilithium_pack_z.sv dilithium-rtl/pqc_dilithium_pack_z_tb.sv

run_test "pack_z_vector" dilithium-rtl/pqc_dilithium_pack_z.sv \
  dilithium-rtl/pqc_dilithium_pack_z_vector.sv dilithium-rtl/pqc_dilithium_pack_z_vector_tb.sv

run_test "pack_h" dilithium-rtl/pqc_dilithium_pack_h.sv dilithium-rtl/pqc_dilithium_pack_h_tb.sv

run_test "pack_sig" dilithium-rtl/pqc_dilithium_pack_z.sv dilithium-rtl/pqc_dilithium_pack_z_vector.sv \
  dilithium-rtl/pqc_dilithium_pack_h.sv dilithium-rtl/pqc_dilithium_pack_sig.sv \
  dilithium-rtl/pqc_dilithium_pack_sig_tb.sv

echo "=================================================="
echo "PASS: kaikki nopeat Sign-komponenttitestit lapaisivat"
echo "=================================================="
