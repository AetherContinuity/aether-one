#!/bin/bash
# NIST ACVP sigGen-FIPS204 KAT-vektori (ML-DSA-65, tgId=10, tcId=139,
# deterministic, signatureInterface=internal, rnd=0). Todentaa RTL
# Sign + pack_sig SUORAAN NIST:n omaa virallista testivektoria vasten
# (EI dilithium-py:n kautta). Sisaltaa AIDON hylkays-ja-uusintayritys-
# tilanteen (kappa 0->5).
set -euo pipefail
cd "$(dirname "$0")"
source dilithium_common_files.sh

echo "Kaannetaan RTL + testipenkki (Sign vs. NIST ACVP sigGen-FIPS204)..."
compile_dilithium_sign sim/dilithium_sign_nist_acvp_sim dilithium-rtl/sign_nist_acvp_tb.sv

echo "Ajetaan simulaatio (odotettu: kappa etenee 0->5, allekirjoitus tasmaa tavu tavulta, ~360000 sykli)..."
vvp sim/dilithium_sign_nist_acvp_sim
