#!/bin/bash
# M5-DILITHIUM-001: VAIHEISTETTU functional flow (kayttajan oma
# ehdotus): KeyGen -> ek.txt/sk_state.txt -> Sign -> sig.txt ->
# Verify -> PASS/FAIL.
#
# JOKAINEN vaihe on OMA, ITSENAINEN Icarus-prosessinsa - muisti
# vapautuu tayysin jokaisen vaiheen valissa. Tama vastaa ASIC/FPGA-
# kehityksen omaa tape-out-/verifiointivuota (erilliset ajot
# tiedostorajapinnoilla), EIKA yksikaan yksittainen ajo kasva kolmen
# paaoperaatio yhdistetyn koon suuruiseksi.
#
# ERI KUIN full_chain_tb.sv (joka yhdistaa KAIKKI KOLME yhdeksi
# valtavaksi simulaatioksi - SAILYTETTY dokumentaationa, EI enaa
# ensisijainen menetelma resurssisyista).
set -euo pipefail
cd "$(dirname "$0")"
source dilithium_common_files.sh

rm -f dilithium-rtl/staged/ek.txt dilithium-rtl/staged/sk_state.txt dilithium-rtl/staged/sig.txt
mkdir -p sim dilithium-rtl/staged

echo "=================================================="
echo "VAIHE 1/3: KeyGen -> ek.txt, sk_state.txt"
echo "=================================================="
iverilog -g2012 -o sim/stage1_keygen \
  rtl/pqc_keccak_pad.sv rtl/pqc_keccak_absorb.sv rtl/pqc_keccak_squeeze.sv rtl/pqc_keccak_f1600.sv rtl/pqc_shake256.sv rtl/pqc_shake128.sv \
  dilithium-rtl/pqc_dilithium_barrett_mulmod.sv dilithium-rtl/pqc_dilithium_ntt_butterfly.sv dilithium-rtl/pqc_dilithium_ntt_core.sv \
  dilithium-rtl/pqc_dilithium_ntt_gs_butterfly.sv dilithium-rtl/pqc_dilithium_ntt_inverse_core.sv \
  dilithium-rtl/pqc_dilithium_rej_ntt_poly.sv dilithium-rtl/pqc_dilithium_expand_a.sv \
  dilithium-rtl/pqc_dilithium_rej_bounded_poly.sv dilithium-rtl/pqc_dilithium_expand_s.sv \
  dilithium-rtl/pqc_dilithium_keygen_core.sv dilithium-rtl/pqc_dilithium_power2round.sv dilithium-rtl/pqc_dilithium_power2round_vector.sv \
  dilithium-rtl/pqc_dilithium_pack_ek.sv dilithium-rtl/pqc_dilithium_pack_s.sv dilithium-rtl/pqc_dilithium_pack_s_vector.sv \
  dilithium-rtl/pqc_dilithium_pack_t0.sv dilithium-rtl/pqc_dilithium_pack_t0_vector.sv dilithium-rtl/pqc_dilithium_pack_dk.sv \
  dilithium-rtl/pqc_dilithium_keygen_top.sv \
  dilithium-rtl/staged/stage1_keygen_tb.sv
vvp sim/stage1_keygen

echo "=================================================="
echo "VAIHE 2/3: Sign (lukee Vaihe 1:n tiedostot) -> sig.txt"
echo "=================================================="
compile_dilithium_sign sim/stage2_sign dilithium-rtl/staged/stage2_sign_tb.sv
vvp sim/stage2_sign

echo "=================================================="
echo "VAIHE 3/3: Verify (lukee Vaihe 1:n ja 2:n tiedostot) -> PASS/FAIL"
echo "=================================================="
iverilog -g2012 -o sim/stage3_verify \
  rtl/pqc_keccak_pad.sv rtl/pqc_keccak_absorb.sv rtl/pqc_keccak_squeeze.sv rtl/pqc_keccak_f1600.sv rtl/pqc_shake256.sv rtl/pqc_shake128.sv \
  dilithium-rtl/pqc_dilithium_barrett_mulmod.sv dilithium-rtl/pqc_dilithium_ntt_butterfly.sv dilithium-rtl/pqc_dilithium_ntt_core.sv \
  dilithium-rtl/pqc_dilithium_ntt_gs_butterfly.sv dilithium-rtl/pqc_dilithium_ntt_inverse_core.sv \
  dilithium-rtl/pqc_dilithium_rej_ntt_poly.sv dilithium-rtl/pqc_dilithium_expand_a.sv \
  dilithium-rtl/pqc_dilithium_decompose.sv dilithium-rtl/pqc_dilithium_pack_w.sv dilithium-rtl/pqc_dilithium_sample_in_ball.sv \
  dilithium-rtl/pqc_dilithium_use_hint.sv \
  dilithium-rtl/pqc_dilithium_unpack_z.sv dilithium-rtl/pqc_dilithium_unpack_z_vector.sv dilithium-rtl/pqc_dilithium_unpack_h.sv \
  dilithium-rtl/pqc_dilithium_verify_core.sv dilithium-rtl/pqc_dilithium_verify_top2.sv \
  dilithium-rtl/staged/stage3_verify_tb.sv
vvp sim/stage3_verify

echo "=================================================="
echo "PASS: KOKO VAIHEISTETTU FUNCTIONAL FLOW (KeyGen->Sign->Verify) LAPI"
echo "=================================================="
