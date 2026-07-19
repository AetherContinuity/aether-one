#!/bin/bash
# dilithium_common_files.sh - keskitetty RTL-tiedostolista ja
# kaannoskomento M5-DILITHIUM-001:n testiskripteille. Sama periaate
# kuin ML-KEM:n oma tau_common_files.sh: yksi totuuden lahde, pienempi
# regressioriski uusia moduuleja lisattaessa. Kaytto: source taman
# tiedoston hardware/pqc-rtl/-hakemistosta (sama konventio kuin
# tau_common_files.sh).

DILITHIUM_RTL_FILES="rtl/pqc_keccak_pad.sv rtl/pqc_keccak_absorb.sv \
  rtl/pqc_keccak_squeeze.sv rtl/pqc_keccak_f1600.sv \
  rtl/pqc_shake256.sv rtl/pqc_shake128.sv \
  dilithium-rtl/pqc_dilithium_barrett_mulmod.sv dilithium-rtl/pqc_dilithium_ntt_butterfly.sv \
  dilithium-rtl/pqc_dilithium_ntt_core.sv \
  dilithium-rtl/pqc_dilithium_ntt_gs_butterfly.sv dilithium-rtl/pqc_dilithium_ntt_inverse_core.sv \
  dilithium-rtl/pqc_dilithium_rej_ntt_poly.sv dilithium-rtl/pqc_dilithium_expand_a.sv \
  dilithium-rtl/pqc_dilithium_rej_bounded_poly.sv dilithium-rtl/pqc_dilithium_expand_s.sv \
  dilithium-rtl/pqc_dilithium_keygen_core.sv dilithium-rtl/pqc_dilithium_power2round.sv \
  dilithium-rtl/pqc_dilithium_power2round_vector.sv \
  dilithium-rtl/pqc_dilithium_pack_ek.sv dilithium-rtl/pqc_dilithium_pack_s.sv \
  dilithium-rtl/pqc_dilithium_pack_s_vector.sv \
  dilithium-rtl/pqc_dilithium_pack_t0.sv dilithium-rtl/pqc_dilithium_pack_t0_vector.sv \
  dilithium-rtl/pqc_dilithium_pack_dk.sv \
  dilithium-rtl/pqc_dilithium_keygen_top.sv \
  dilithium-rtl/pqc_dilithium_decompose.sv dilithium-rtl/pqc_dilithium_use_hint.sv \
  dilithium-rtl/pqc_dilithium_sample_in_ball.sv \
  dilithium-rtl/pqc_dilithium_unpack_z.sv dilithium-rtl/pqc_dilithium_unpack_z_vector.sv \
  dilithium-rtl/pqc_dilithium_unpack_h.sv \
  dilithium-rtl/pqc_dilithium_pack_w.sv dilithium-rtl/pqc_dilithium_verify_core.sv \
  dilithium-rtl/pqc_dilithium_verify_top2.sv"

compile_dilithium() {
  local out="$1"
  shift
  iverilog -g2012 -o "$out" $DILITHIUM_RTL_FILES "$@"
}
