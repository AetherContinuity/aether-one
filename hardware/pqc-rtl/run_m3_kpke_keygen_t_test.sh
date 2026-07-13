#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/3] Generoidaan vektorit (uudelleenkaytetaan Kerros 2:n omat + uusi t_hat)..."
python3 m2-golden/gen_full_ntt_vectors.py > /dev/null
python3 m2-golden/gen_amatrix_vectors.py > /dev/null
python3 m2-golden/gen_se_vectors.py > /dev/null
python3 m2-golden/gen_kpke_keygen_t_vectors.py

echo "[2/3] Kaannetaan RTL + testipenkki..."
iverilog -g2012 -o sim/m3_kpke_keygen_t_sim \
  rtl/pqc_rvv_cluster_2lane.sv rtl/pqc_ntt_stage_banked.sv \
  rtl/pqc_basecasemul.sv rtl/pqc_multiplyntts.sv rtl/pqc_polyadd.sv \
  tb/pqc_kpke_keygen_t_tb.sv

echo "[3/3] Ajetaan simulaatio..."
vvp sim/m3_kpke_keygen_t_sim
