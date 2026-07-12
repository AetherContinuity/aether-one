#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/2] Generoidaan vektorit..."
python3 m2-golden/gen_byteencode_dparam_vectors.py

echo "[2/2] Kaannetaan ja ajetaan jokainen d-arvo..."
for D in 4 5 10 11 12; do
  echo "=== d=$D ==="
  iverilog -g2012 -o sim/m3_byteencode_d${D}_sim rtl/pqc_byteencode_dparam.sv tb/pqc_byteencode_d${D}_tb.sv
  vvp sim/m3_byteencode_d${D}_sim
done
