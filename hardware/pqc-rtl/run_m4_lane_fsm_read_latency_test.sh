#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/2] Kaannetaan RTL + testipenkki..."
iverilog -g2012 -o sim/m4_lane_fsm_read_latency_sim \
  rtl/pqc_rvv_cluster_2lane.sv tb/pqc_lane_fsm_read_latency_tb.sv

echo "[2/2] Ajetaan simulaatio..."
timeout 30 vvp sim/m4_lane_fsm_read_latency_sim
