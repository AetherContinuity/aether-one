#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source dilithium_common_files.sh

echo "[1/2] Kaannetaan RTL + testipenkki (Verify - aito allekirjoitus)..."
compile_dilithium sim/dilithium_verify_positive_sim dilithium-rtl/pqc_dilithium_verify_top2_tb.sv

echo "[2/2] Ajetaan simulaatio (odotettu: verify_ok=1, ~115000 sykli)..."
vvp sim/dilithium_verify_positive_sim
