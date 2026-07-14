#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/3] Generoidaan vektorit..."
python3 m2-golden/gen_full_ntt_vectors.py > /dev/null
python3 m2-golden/gen_kpke_keygen_multiseed_vectors.py

echo "[2/3] Kaannetaan RTL + testipenkki..."
iverilog -g2012 -o sim/m3_kpke_keygen_multiseed_sim \
  rtl/pqc_keccak_f1600.sv rtl/pqc_keccak_pad.sv rtl/pqc_keccak_absorb.sv \
  rtl/pqc_keccak_squeeze.sv rtl/pqc_shake128.sv rtl/pqc_shake256.sv \
  rtl/pqc_sha3_256.sv rtl/pqc_sha3_512.sv \
  rtl/pqc_samplentt_reject.sv rtl/pqc_samplentt.sv rtl/pqc_samplepolycbd.sv \
  rtl/pqc_prf_samplepolycbd.sv \
  rtl/pqc_rvv_cluster_2lane.sv rtl/pqc_ntt_stage_banked.sv \
  rtl/pqc_basecasemul.sv rtl/pqc_multiplyntts.sv rtl/pqc_polyadd.sv \
  rtl/pqc_byteencode_dparam.sv \
  tb/pqc_kpke_keygen_multiseed_tb.sv

echo "[3/3] Ajetaan simulaatio..."
timeout 300 vvp sim/m3_kpke_keygen_multiseed_sim
