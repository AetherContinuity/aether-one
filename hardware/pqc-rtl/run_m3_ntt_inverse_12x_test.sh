#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/2] Kaannetaan RTL + testipenkki..."
iverilog -g2012 -o sim/m3_ntt_inverse_12x_sim \
  rtl/pqc_rvv_cluster_2lane.sv rtl/pqc_ntt_stage_banked.sv \
  tb/pqc_ntt_inverse_12x_isolated_tb.sv

echo "[2/2] Ajetaan simulaatio..."
vvp sim/m3_ntt_inverse_12x_sim
