#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source dilithium_common_files.sh

echo "[1/2] Kaannetaan RTL + testipenkki (Verify - turmeltu julkinen avain)..."
compile_dilithium sim/dilithium_verify_neg_pk_sim dilithium-rtl/pqc_dilithium_verify_top2_neg_pk_tb.sv

echo "[2/2] Ajetaan simulaatio (odotettu: verify_ok=0, JULKINEN AVAIN turmeltu)..."
vvp sim/dilithium_verify_neg_pk_sim
