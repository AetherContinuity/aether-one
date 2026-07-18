#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/3] Generoidaan vektorit..."
python3 m2-golden/gen_full_ntt_vectors.py > /dev/null
python3 m2-golden/gen_mlkem_keygen_vectors.py > /dev/null

echo "[2/3] Kaannetaan RTL + testipenkki..."
iverilog -g2012 -o sim/m4_tau_watchdog_interrupt_sim \
  rtl/pqc_rvv_cluster_2lane.sv rtl/pqc_ntt_stage_banked.sv \
  rtl/pqc_samplentt_reject.sv rtl/pqc_samplentt.sv \
  rtl/pqc_keccak_pad.sv rtl/pqc_keccak_absorb.sv rtl/pqc_keccak_squeeze.sv rtl/pqc_keccak_f1600.sv \
  rtl/pqc_sha3_512.sv rtl/pqc_sha3_256.sv rtl/pqc_shake128.sv rtl/pqc_shake256.sv \
  rtl/pqc_samplepolycbd.sv rtl/pqc_prf_samplepolycbd.sv \
  rtl/pqc_byteencode_dparam.sv rtl/pqc_byteencode_d1.sv \
  rtl/pqc_multiplyntts.sv rtl/pqc_basecasemul.sv rtl/pqc_polyadd.sv rtl/pqc_polysub.sv \
  rtl/pqc_ntt_final_scale.sv rtl/pqc_compress.sv rtl/pqc_batch_compress.sv rtl/pqc_batch_decompress.sv \
  fpga/tau/pqc_mlkem_keygen_core.sv fpga/tau/pqc_mlkem_decaps_a_core.sv \
  fpga/tau/pqc_mlkem_decaps_b1_core.sv fpga/tau/pqc_mlkem_decaps_top.sv \
  fpga/tau/pqc_mlkem_encaps_top.sv \
  fpga/tau/pqc_tau_audit_log.sv fpga/tau/pqc_tau_watchdog.sv \
  fpga/tau/pqc_tau_integrated_wrapper.sv fpga/tau/pqc_tau_watchdog_interrupt_tb.sv

echo "[3/3] Ajetaan simulaatio (M4-TAU-001: watchdog keskeyttaa KeyGenin, audit-loki erottaa tapahtuman)..."
vvp sim/m4_tau_watchdog_interrupt_sim
