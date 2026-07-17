#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/2] Kaannetaan RTL + testipenkki..."
iverilog -g2012 -o sim/m4_tau_audit_multiword_sim \
  rtl/pqc_rvv_cluster_2lane.sv rtl/pqc_ntt_stage_banked.sv \
  rtl/pqc_keccak_pad.sv rtl/pqc_keccak_absorb.sv rtl/pqc_keccak_squeeze.sv rtl/pqc_keccak_f1600.sv \
  rtl/pqc_sha3_512.sv rtl/pqc_sha3_256.sv rtl/pqc_shake128.sv rtl/pqc_shake256.sv \
  rtl/pqc_samplentt_reject.sv rtl/pqc_samplentt.sv rtl/pqc_samplepolycbd.sv rtl/pqc_prf_samplepolycbd.sv \
  rtl/pqc_multiplyntts.sv rtl/pqc_basecasemul.sv rtl/pqc_polyadd.sv rtl/pqc_byteencode_dparam.sv \
  fpga/tau/pqc_mlkem_keygen_core.sv fpga/tau/pqc_tau_audit_log.sv fpga/tau/pqc_tau_watchdog.sv \
  fpga/tau/pqc_tau_integrated_wrapper.sv fpga/tau/pqc_tau_audit_multiword_tb.sv

echo "[2/2] Ajetaan simulaatio (M4-TAU-001: AUDIT_WORD_SEL toimii kaikilla sanoilla - regressio 2026-07-19 loydettyyn bugiin)..."
vvp sim/m4_tau_audit_multiword_sim
