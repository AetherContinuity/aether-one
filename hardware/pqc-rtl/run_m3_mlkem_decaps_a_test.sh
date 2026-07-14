#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/3] Generoidaan vektorit..."
python3 m2-golden/gen_full_ntt_vectors.py > /dev/null
python3 m2-golden/gen_ntt_inverse_schedule.py > /dev/null
python3 m2-golden/gen_mlkem_decaps_a_vectors.py

echo "[2/3] Kaannetaan RTL + testipenkki..."
iverilog -g2012 -o sim/m3_mlkem_decaps_a_sim \
  rtl/pqc_sha3_512.sv rtl/pqc_keccak_f1600.sv rtl/pqc_keccak_pad.sv \
  rtl/pqc_keccak_absorb.sv rtl/pqc_keccak_squeeze.sv \
  rtl/pqc_rvv_cluster_2lane.sv rtl/pqc_ntt_stage_banked.sv rtl/pqc_ntt_final_scale.sv \
  rtl/pqc_basecasemul.sv rtl/pqc_multiplyntts.sv rtl/pqc_polyadd.sv rtl/pqc_polysub.sv \
  rtl/pqc_compress.sv rtl/pqc_batch_decompress.sv \
  rtl/pqc_byteencode_dparam.sv rtl/pqc_byteencode_d1.sv \
  tb/pqc_mlkem_decaps_a_tb.sv

echo "[3/3] Ajetaan simulaatio..."
timeout 60 vvp sim/m3_mlkem_decaps_a_sim
