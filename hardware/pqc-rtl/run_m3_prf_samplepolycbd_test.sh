#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/3] Generoidaan vektorit..."
python3 m2-golden/gen_prf_samplepolycbd_vectors.py

echo "[2/3] Kaannetaan RTL + testipenkki..."
iverilog -g2012 -o sim/m3_prf_cbd_sim \
  rtl/pqc_keccak_f1600.sv rtl/pqc_keccak_pad.sv rtl/pqc_keccak_absorb.sv \
  rtl/pqc_keccak_squeeze.sv rtl/pqc_shake256.sv rtl/pqc_samplepolycbd.sv \
  rtl/pqc_prf_samplepolycbd.sv tb/pqc_prf_samplepolycbd_tb.sv

echo "[3/3] Ajetaan simulaatio..."
vvp sim/m3_prf_cbd_sim
