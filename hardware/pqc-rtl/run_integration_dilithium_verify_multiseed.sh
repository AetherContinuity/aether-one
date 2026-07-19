#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source dilithium_common_files.sh

echo "[1/2] Kaannetaan RTL + testipenkki (Verify - kolme riippumatonta avainparia)..."
compile_dilithium sim/dilithium_verify_multiseed_sim dilithium-rtl/pqc_dilithium_verify_top2_multiseed_tb.sv

echo "[2/2] Ajetaan simulaatio (odotettu: verify_ok=1 kaikille kolmelle siemenelle)..."
vvp sim/dilithium_verify_multiseed_sim
