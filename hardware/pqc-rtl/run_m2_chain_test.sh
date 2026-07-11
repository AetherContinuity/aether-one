#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/3] Generoidaan vektorit..."
python3 m2-golden/gen_chain_vectors.py

echo "[2/3] Kaannetaan RTL + testipenkki..."
iverilog -g2012 -o sim/m2_chain_sim rtl/pqc_rvv_cluster_2lane.sv rtl/pqc_ntt_stage_2lane.sv tb/pqc_ntt_chain_tb.sv

echo "[3/3] Ajetaan simulaatio..."
vvp sim/m2_chain_sim
