#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/3] Generoidaan aikataulut ja golden-valitilat (data-riippumaton)..."
python3 m2-golden/gen_full_ntt_vectors.py > /dev/null
python3 m2-golden/gen_ntt_inverse_schedule.py > /dev/null
python3 m2-golden/gen_ntt_inverse_stage_snapshots.py

echo "[2/3] Kaannetaan RTL + testipenkki..."
iverilog -g2012 -o sim/m3_ntt_inverse_stage_debug_sim \
  rtl/pqc_rvv_cluster_2lane.sv rtl/pqc_ntt_stage_banked.sv \
  tb/pqc_ntt_inverse_stage_debug_tb.sv

echo "[3/3] Ajetaan simulaatio..."
vvp sim/m3_ntt_inverse_stage_debug_sim
