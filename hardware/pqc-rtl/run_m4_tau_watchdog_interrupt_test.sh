#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source tau_common_files.sh

echo "[1/3] Generoidaan vektorit..."
python3 m2-golden/gen_full_ntt_vectors.py > /dev/null
python3 m2-golden/gen_mlkem_keygen_vectors.py > /dev/null

echo "[2/3] Kaannetaan RTL + testipenkki..."
compile_tau sim/m4_tau_watchdog_interrupt_sim fpga/tau/pqc_tau_watchdog_interrupt_tb.sv

echo "[3/3] Ajetaan simulaatio (M4-TAU-001: watchdog keskeyttaa KeyGenin, audit-loki erottaa tapahtuman)..."
vvp sim/m4_tau_watchdog_interrupt_sim
