#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source tau_common_files.sh

echo "[1/2] Kaannetaan RTL + testipenkki..."
compile_tau sim/m4_tau_full_protocol_sim fpga/tau/pqc_tau_full_protocol_tb.sv

echo "[2/2] Ajetaan simulaatio (koko ML-KEM-protokolla: KeyGen->Encaps->Decaps)..."
vvp sim/m4_tau_full_protocol_sim
