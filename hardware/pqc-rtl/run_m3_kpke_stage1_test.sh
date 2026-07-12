#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/3] Generoidaan vektorit..."
python3 m2-golden/kpke_decrypt_golden.py

echo "[2/3] Kaannetaan RTL + testipenkki..."
iverilog -g2012 -o sim/m3_kpke_stage1_sim \
  rtl/pqc_byteencode_dparam.sv rtl/pqc_compress.sv rtl/pqc_batch_decompress.sv \
  tb/pqc_kpke_stage1_tb.sv

echo "[3/3] Ajetaan simulaatio..."
vvp sim/m3_kpke_stage1_sim
