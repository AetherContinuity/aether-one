#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source tau_common_files.sh

echo "[1/2] Kaannetaan RTL + testipenkki..."
compile_tau sim/m4_tau_encaps_wishbone_sim fpga/tau/pqc_tau_encaps_wishbone_tb.sv

echo "[2/2] Ajetaan simulaatio (Encaps-Wishbone-integraatio)..."
vvp sim/m4_tau_encaps_wishbone_sim
