#!/bin/bash
# ML-KEM-512 RTL vs. NIST ACVP -vektorit (FIPS 203), CI-regressio.
#
# Ajaa samat testipenkit, joilla M3_MLKEM_ACVP_STATUS.md:n tulokset
# saatiin, jokaisella pushilla:
#   KeyGen  1 vektori  (vectors/mlkem_keygen_nist_vector.txt)
#   Encaps  3 vektoria (fpga/tau/acvp/encaps_tc{1,2,3}.txt)
#   Decaps  5 vektoria (fpga/tau/decaps_top_nist_vectors.txt)
#
# NEGATIIVIKONTROLLI: jokaisen operaation vektorista tehdaan kopio, josta
# yksi heksamerkki on muutettu. Testipenkin TAYTYY epaonnistua silla.
# Jos se menee lapi, testi ei suojaa mitaan ja skripti palauttaa virheen.
#
# Tulos luetaan simulaation tulosteesta (PASS-rivi loytyy JA FAIL-rivia
# ei ole), ei pelkasta vvp:n paluukoodista.
set -uo pipefail
cd "$(dirname "$0")"
source tau_common_files.sh
mkdir -p sim

KEYGEN_FILES="rtl/pqc_keccak_f1600.sv rtl/pqc_keccak_pad.sv rtl/pqc_keccak_absorb.sv \
  rtl/pqc_keccak_squeeze.sv rtl/pqc_shake128.sv rtl/pqc_shake256.sv \
  rtl/pqc_sha3_256.sv rtl/pqc_sha3_512.sv \
  rtl/pqc_samplentt_reject.sv rtl/pqc_samplentt.sv rtl/pqc_samplepolycbd.sv \
  rtl/pqc_prf_samplepolycbd.sv \
  rtl/pqc_rvv_cluster_2lane.sv rtl/pqc_ntt_stage_banked.sv \
  rtl/pqc_basecasemul.sv rtl/pqc_multiplyntts.sv rtl/pqc_polyadd.sv \
  rtl/pqc_byteencode_dparam.sv"

FAILED=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# $1 = nimi, $2 = sim-binaari, $3 = vektoritiedosto, $4 = odotus (pass|fail)
run_case() {
  local name="$1" sim="$2" vec="$3" expect="$4" out result
  out="$(vvp "$sim" +VEC="$vec" 2>&1)"
  if echo "$out" | grep -q "^PASS" && ! echo "$out" | grep -q "FAIL"; then
    result=pass
  else
    result=fail
  fi
  if [ "$result" = "$expect" ]; then
    echo "  ok    $name (odotettu: $expect)"
  else
    echo "  VIRHE $name: odotettu $expect, saatu $result"
    echo "$out" | grep -E "PASS|FAIL|fatal" | tail -5 | sed 's/^/        /'
    FAILED=1
  fi
}

# Muuta tiedoston viimeisen rivin viimeinen heksamerkki (0<->1, muut -> 0).
corrupt() {
  python3 - "$1" "$2" <<'PY'
import sys
lines = open(sys.argv[1]).read().split("\n")
i = max(k for k, l in enumerate(lines) if l.strip())
last = lines[i]
lines[i] = last[:-1] + ("1" if last[-1] == "0" else "0")
open(sys.argv[2], "w").write("\n".join(lines))
PY
}

echo "[1/4] Generoidaan NTT-aikataulu (KeyGen-testipenkin syote)..."
python3 m2-golden/gen_full_ntt_vectors.py > /dev/null

echo "[2/4] Kaannetaan testipenkit..."
iverilog -g2012 -o sim/acvp_mlkem_keygen_sim $KEYGEN_FILES tb/pqc_mlkem_keygen_nist_tb.sv 2>&1 | grep -v "sorry" || true
compile_tau sim/acvp_mlkem_encaps_sim fpga/tau/pqc_mlkem_encaps_top_nist_tb.sv 2>&1 | grep -v "sorry" || true
compile_tau sim/acvp_mlkem_decaps_sim fpga/tau/decaps_nist_multi_tb.sv 2>&1 | grep -v "sorry" || true
for s in keygen encaps decaps; do
  [ -f "sim/acvp_mlkem_${s}_sim" ] || { echo "VIRHE: sim/acvp_mlkem_${s}_sim ei kaantynyt"; exit 1; }
done

echo "[3/4] NIST ACVP -vektorit..."
run_case "KeyGen keyGen-FIPS203"            sim/acvp_mlkem_keygen_sim vectors/mlkem_keygen_nist_vector.txt pass
for t in 1 2 3; do
  run_case "Encaps encapDecap-FIPS203 tcId=$t" sim/acvp_mlkem_encaps_sim "fpga/tau/acvp/encaps_tc$t.txt" pass
done
run_case "Decaps encapDecap-FIPS203, 5 tapausta" sim/acvp_mlkem_decaps_sim fpga/tau/decaps_top_nist_vectors.txt pass

echo "[4/4] Negatiivikontrolli (yksi heksamerkki muutettu -> testin taytyy epaonnistua)..."
corrupt vectors/mlkem_keygen_nist_vector.txt       "$TMP/keygen.txt"
corrupt fpga/tau/acvp/encaps_tc1.txt               "$TMP/encaps.txt"
corrupt fpga/tau/decaps_top_nist_vectors.txt       "$TMP/decaps.txt"
run_case "KeyGen, turmeltu vektori" sim/acvp_mlkem_keygen_sim "$TMP/keygen.txt" fail
run_case "Encaps, turmeltu vektori" sim/acvp_mlkem_encaps_sim "$TMP/encaps.txt" fail
run_case "Decaps, turmeltu vektori" sim/acvp_mlkem_decaps_sim "$TMP/decaps.txt" fail

if [ "$FAILED" -ne 0 ]; then
  echo "ACVP-regressio: VIRHEITA"
  exit 1
fi
echo "ACVP-regressio: KeyGen 1, Encaps 3, Decaps 5 vektoria; 3 negatiivikontrollia."
