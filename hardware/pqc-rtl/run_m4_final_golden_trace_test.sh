#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/2] Generoidaan vektorit..."
python3 m2-golden/gen_full_ntt_vectors.py > /dev/null

echo "[2/2] Kaannetaan ja ajetaan lopullinen golden trace (NTT_READ_LATENCY=0 vs 1+bringup, tuotantoydin)..."
iverilog -g2012 -o sim/m4_final_golden_trace_sim rtl/pqc_rvv_cluster_2lane.sv rtl/pqc_ntt_stage_banked.sv tb/pqc_ntt_stage_banked_final_golden_trace_tb.sv
timeout 60 vvp sim/m4_final_golden_trace_sim
