#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source tau_common_files.sh

echo "[1/2] Kaannetaan RTL + testipenkki..."
iverilog -g2012 -o sim/m4_tau_decaps_wishbone_sim \
  $TAU_RTL_FILES fpga/tau/pqc_tau_decaps_wishbone_tb.sv

echo "[2/2] Ajetaan simulaatio (Decaps-Wishbone-integraatio)..."
vvp sim/m4_tau_decaps_wishbone_sim
