#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source tau_common_files.sh

echo "[1/2] Kaannetaan RTL + testipenkki..."
compile_tau sim/m4_tau_audit_multiword_sim fpga/tau/pqc_tau_audit_multiword_tb.sv

echo "[2/2] Ajetaan simulaatio (M4-TAU-001: AUDIT_WORD_SEL toimii kaikilla sanoilla - regressio 2026-07-19 loydettyyn bugiin)..."
vvp sim/m4_tau_audit_multiword_sim
