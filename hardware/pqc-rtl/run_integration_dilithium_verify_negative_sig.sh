#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source dilithium_common_files.sh

echo "[1/2] Kaannetaan RTL + testipenkki (Verify - turmeltu allekirjoitus)..."
compile_dilithium sim/dilithium_verify_neg_sig_sim dilithium-rtl/pqc_dilithium_verify_top2_neg_tb.sv

echo "[2/2] Ajetaan simulaatio (odotettu: verify_ok=0, allekirjoitus HYLATTAVA)..."
vvp sim/dilithium_verify_neg_sig_sim
