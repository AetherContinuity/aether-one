#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source tau_common_files.sh

echo "[1/2] Kaannetaan RTL + testipenkki..."
compile_tau sim/m4_tau_decaps_audit_sim fpga/tau/pqc_tau_decaps_audit_tb.sv
compile_tau sim/m4_tau_decaps_audit_sim_k2 fpga/tau/pqc_tau_decaps_audit_tb.sv -P pqc_tau_decaps_audit_tb.K=2

echo "[2/2] Ajetaan simulaatio (Decaps omat audit-tapahtumat)..."
echo "--- K=3 (ML-KEM-768, oletus) ---"
vvp sim/m4_tau_decaps_audit_sim
echo "--- K=2 (ML-KEM-512) ---"
vvp sim/m4_tau_decaps_audit_sim_k2
