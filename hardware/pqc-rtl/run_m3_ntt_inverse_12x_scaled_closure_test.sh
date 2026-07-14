#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/2] Kaannetaan RTL + testipenkki (mukaan lukien pqc_ntt_final_scale)..."
iverilog -g2012 -o sim/m3_ntt_inv_12x_scaled_sim \
  rtl/pqc_rvv_cluster_2lane.sv rtl/pqc_ntt_stage_banked.sv rtl/pqc_ntt_final_scale.sv \
  tb/pqc_ntt_inverse_12x_scaled_closure_tb.sv

echo "[2/2] Ajetaan simulaatio..."
timeout 60 vvp sim/m3_ntt_inv_12x_scaled_sim
