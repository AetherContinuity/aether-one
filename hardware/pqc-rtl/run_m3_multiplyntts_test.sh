#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/3] Generoidaan vektorit..."
python3 m2-golden/gen_multiplyntts_vectors.py

echo "[2/3] Kaannetaan RTL + testipenkki..."
iverilog -g2012 -o sim/m3_multiplyntts_sim rtl/pqc_basecasemul.sv rtl/pqc_multiplyntts.sv tb/pqc_multiplyntts_tb.sv

echo "[3/3] Ajetaan simulaatio..."
vvp sim/m3_multiplyntts_sim
