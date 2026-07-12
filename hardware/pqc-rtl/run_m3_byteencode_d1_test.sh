#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/3] Generoidaan vektorit..."
python3 m2-golden/gen_byteencode_d1_vectors.py

echo "[2/3] Kaannetaan RTL + testipenkki..."
iverilog -g2012 -o sim/m3_byteencode_d1_sim rtl/pqc_byteencode_d1.sv tb/pqc_byteencode_d1_tb.sv

echo "[3/3] Ajetaan simulaatio..."
vvp sim/m3_byteencode_d1_sim
