#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/3] Generoidaan vektorit..."
python3 m2-golden/gen_samplepolycbd_frozen_reference.py
python3 m2-golden/gen_samplepolycbd_vectors.py

echo "[2/3] Kaannetaan RTL + testipenkki..."
iverilog -g2012 -o sim/m3_samplepolycbd_sim rtl/pqc_samplepolycbd.sv tb/pqc_samplepolycbd_tb.sv

echo "[3/3] Ajetaan simulaatio..."
vvp sim/m3_samplepolycbd_sim
