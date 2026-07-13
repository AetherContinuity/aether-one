#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/2] Generoidaan testivektorit jaadytetysta referenssista..."
python3 m2-golden/gen_keccak_f1600_tb_vectors.py

echo "[2/2] Kaannetaan ja ajetaan..."
iverilog -g2012 -o sim/m3_keccak_f1600_sim rtl/pqc_keccak_f1600.sv tb/pqc_keccak_f1600_tb.sv
vvp sim/m3_keccak_f1600_sim
