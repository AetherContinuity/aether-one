#!/bin/bash
# ML-DSA-65 RTL vs. NIST ACVP -vektorit (FIPS 204): KeyGen ja Verify.
#
# Samat testipenkit ja vektorit kuin dilithium-rtl/NIST_ACVP_STATUS.md:ssa:
#   KeyGen  keyGen-FIPS204  tcId=26   (~87 000 syklia)
#   Verify  sigVer-FIPS204  tcId=140  (~115 000 syklia, hylkaystapaus)
# Sign-ACVP on raskaampi ja pysyy kasin kaynnistettavassa workflow'ssa
# (run_integration_dilithium_sign_nist_acvp.sh).
#
# Tulos luetaan simulaation tulosteesta (PASS-rivi loytyy JA FAIL-rivia
# ei ole). Negatiivikontrollia ei ole: Verify-vektori on itse hylkays-
# tapaus (testPassed=0), joten turmeltu syote antaisi saman tuloksen.
set -uo pipefail
cd "$(dirname "$0")"
source dilithium_common_files.sh
mkdir -p sim

FAILED=0
run_tb() {
  local name="$1" sim="$2" tb="$3" out
  echo "Kaannetaan: $name"
  compile_dilithium "$sim" "$tb" 2>&1 | grep -v "sorry" || true
  [ -f "$sim" ] || { echo "  VIRHE: $sim ei kaantynyt"; FAILED=1; return; }
  echo "Ajetaan:    $name"
  out="$(vvp "$sim" 2>&1)"
  echo "$out" | grep -E "sykli|PASS|FAIL" | sed 's/^/  /'
  if echo "$out" | grep -q "^PASS" && ! echo "$out" | grep -q "FAIL"; then
    echo "  ok    $name"
  else
    echo "  VIRHE $name"
    FAILED=1
  fi
}

run_tb "KeyGen keyGen-FIPS204 tcId=26" sim/acvp_dilithium_keygen_sim dilithium-rtl/nist_acvp_keygen_tb.sv
run_tb "Verify sigVer-FIPS204 tcId=140" sim/acvp_dilithium_verify_sim dilithium-rtl/nist_acvp_verify_tb.sv

if [ "$FAILED" -ne 0 ]; then
  echo "ACVP-regressio (ML-DSA-65): VIRHEITA"
  exit 1
fi
echo "ACVP-regressio (ML-DSA-65): KeyGen 1, Verify 1 vektori."
