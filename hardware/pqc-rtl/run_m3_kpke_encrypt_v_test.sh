#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/3] Generoidaan vektorit..."
python3 m2-golden/gen_full_ntt_vectors.py > /dev/null
python3 m2-golden/gen_ntt_inverse_schedule.py > /dev/null
python3 m2-golden/gen_kpke_encrypt_v_vectors.py

echo "[2/3] Kaannetaan RTL + testipenkki..."
iverilog -g2012 -o sim/m3_kpke_encrypt_v_sim \
  rtl/pqc_rvv_cluster_2lane.sv rtl/pqc_ntt_stage_banked.sv rtl/pqc_ntt_final_scale.sv \
  rtl/pqc_basecasemul.sv rtl/pqc_multiplyntts.sv rtl/pqc_polyadd.sv \
  tb/pqc_kpke_encrypt_v_tb.sv

echo "[3/3] Ajetaan simulaatio..."
vvp sim/m3_kpke_encrypt_v_sim
