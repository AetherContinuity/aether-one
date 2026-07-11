#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/3] Generoidaan vektorit ja aikataulu..."
python3 m2-golden/gen_full_ntt_vectors.py > /dev/null

echo "[2/3] Kaannetaan RTL + testipenkki..."
iverilog -g2012 -o sim/m2_perf_sim rtl/pqc_rvv_cluster_2lane.sv rtl/pqc_ntt_stage_banked.sv tb/pqc_ntt_full_banked_perf_tb.sv

echo "[3/3] Ajetaan simulaatio..."
vvp sim/m2_perf_sim
