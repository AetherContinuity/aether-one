#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/3] Generoidaan vektorit..."
python3 gen_vectors.py

echo "[2/3] Kaannetaan RTL + testipenkki..."
iverilog -g2012 -o sim/m1_sim rtl/pqc_rvv_cluster_2lane.sv tb/pqc_cluster_m1_tb.sv

echo "[3/3] Ajetaan simulaatio..."
vvp sim/m1_sim
