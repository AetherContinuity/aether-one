#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source tau_common_files.sh

echo "[1/3] Generoidaan vektorit..."
python3 m2-golden/gen_full_ntt_vectors.py > /dev/null
python3 m2-golden/gen_mlkem_keygen_vectors.py > /dev/null

echo "[2/3] Kaannetaan RTL + testipenkki..."
compile_tau sim/m4_tau_watchdog_interrupt_sim fpga/tau/pqc_tau_watchdog_interrupt_tb.sv
compile_tau sim/m4_tau_watchdog_interrupt_sim_k2 fpga/tau/pqc_tau_watchdog_interrupt_tb.sv -P pqc_tau_watchdog_interrupt_tb.K=2

echo "[3/3] Ajetaan simulaatio (M4-TAU-001: watchdog keskeyttaa KeyGenin, audit-loki erottaa tapahtuman)..."
echo "--- K=3 (ML-KEM-768, oletus) ---"
vvp sim/m4_tau_watchdog_interrupt_sim
echo "--- K=2 (ML-KEM-512) ---"
vvp sim/m4_tau_watchdog_interrupt_sim_k2
