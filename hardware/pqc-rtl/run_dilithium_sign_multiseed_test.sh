#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source dilithium_common_files.sh

echo "[1/2] Kaannetaan RTL + testipenkki (Sign - kolme riippumatonta siementa)..."
compile_dilithium_sign sim/dilithium_sign_multiseed_sim dilithium-rtl/pqc_dilithium_sign_top2_multiseed_tb.sv

echo "[2/2] Ajetaan simulaatio (odotettu: kaikki kolme siementa tasmaavat, ~726000 sykli yhteensa)..."
vvp sim/dilithium_sign_multiseed_sim
