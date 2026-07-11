#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/3] Varmistetaan level6-vektorit (samat kuin 2b)..."
python3 m2-golden/gen_level6_vectors.py > /dev/null

echo "[2/3] Kaannetaan RTL + testipenkki..."
iverilog -g2012 -o sim/m2_banked_sim rtl/pqc_rvv_cluster_2lane.sv rtl/pqc_ntt_level6_banked.sv tb/pqc_ntt_level6_banked_tb.sv

echo "[3/3] Ajetaan simulaatio..."
vvp sim/m2_banked_sim
