#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source dilithium_common_files.sh

echo "[1/2] Kaannetaan RTL + testipenkki (Sign - koko hylkayssilmukka + pakkaus)..."
compile_dilithium_sign sim/dilithium_sign_positive_sim dilithium-rtl/pqc_dilithium_sign_top2_tb.sv

echo "[2/2] Ajetaan simulaatio (odotettu: c_tilde/z/h kaikki tasmaavat, ~242000 sykli)..."
vvp sim/dilithium_sign_positive_sim
