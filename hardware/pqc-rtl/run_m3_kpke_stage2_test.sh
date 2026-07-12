#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/3] Generoidaan vektorit (KPKE + NTT-aikataulu, data-riippumaton)..."
python3 m2-golden/kpke_decrypt_golden.py
python3 m2-golden/gen_full_ntt_vectors.py > /dev/null

echo "[2/3] Kaannetaan RTL + testipenkki..."
iverilog -g2012 -o sim/m3_kpke_stage2_sim \
  rtl/pqc_rvv_cluster_2lane.sv rtl/pqc_ntt_stage_banked.sv \
  rtl/pqc_basecasemul.sv rtl/pqc_multiplyntts.sv rtl/pqc_polyadd.sv \
  tb/pqc_kpke_stage2_tb.sv

echo "[3/3] Ajetaan simulaatio..."
vvp sim/m3_kpke_stage2_sim
