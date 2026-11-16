#!/bin/bash
# ML-KEM synteesikelpoiset ytimet vs. NIST ACVP, kaikki ML-KEM-512- tai
# ML-KEM-768-tapaukset (KeyGen 25, Encaps 25, Decaps 10).
#
# Kaytto: run_acvp_mlkem_full.sh 512|768 [--verify-source]
#
# Testattavat moduulit: pqc_mlkem_keygen_core, pqc_mlkem_encaps_top,
# pqc_mlkem_decaps_top (fpga/tau/), testipenkki fpga/tau/mlkem_acvp_tb.sv.
# Vektorit: fpga/tau/acvp/{keygen,encaps,decaps}_<sarja>.txt.
#
# --verify-source: hakee NIST:n JSON-tiedostot kiinnitetysta commitista,
# tarkistaa sha256:n, generoi vektorit uudelleen (generaattori vertaa
# jokaista tapausta myos golden-malliin) ja vaatii, etta tulos on
# tavulleen sama kuin repossa oleva. Vaatii verkon.
#
# NEGATIIVIKONTROLLI: jokaisesta vektoritiedostosta tehdaan kopio, jonka
# viimeisen rivin viimeinen heksamerkki on muutettu. Testipenkin TAYTYY
# epaonnistua silla.
set -uo pipefail
cd "$(dirname "$0")"
source tau_common_files.sh
mkdir -p sim

PSET="${1:-}"
case "$PSET" in
  512) K=2 ;;
  768) K=3 ;;
  *) echo "kaytto: $0 512|768 [--verify-source]"; exit 2 ;;
esac

ACVP_COMMIT=975de31eb83d87039ec88934fdc47d8c312b892d
KG_SHA=d7a62a2c3476957f56dd8d24f9004ea6776ccfe995ffe71a65bb9506dc9c7b1b
ED_SHA=a556952ce869bb89c3a3196a701dad89647c193a34c86eafb61a9d710d5b810f

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILED=0

if [ "${2:-}" = "--verify-source" ]; then
  echo "[0] NIST-lahde: haku, sha256, uudelleengenerointi..."
  base="https://raw.githubusercontent.com/usnistgov/ACVP-Server/$ACVP_COMMIT/gen-val/json-files"
  curl -sSfL -o "$TMP/kg.json" "$base/ML-KEM-keyGen-FIPS203/internalProjection.json" || exit 1
  curl -sSfL -o "$TMP/ed.json" "$base/ML-KEM-encapDecap-FIPS203/internalProjection.json" || exit 1
  echo "$KG_SHA  $TMP/kg.json" | sha256sum -c --quiet || exit 1
  echo "$ED_SHA  $TMP/ed.json" | sha256sum -c --quiet || exit 1
  mkdir -p "$TMP/gen"
  python3 m2-golden/gen_mlkem_acvp_vectors.py "ML-KEM-$PSET" "$TMP/kg.json" "$TMP/ed.json" "$TMP/gen" || exit 1
  for op in keygen encaps decaps; do
    if ! cmp -s "$TMP/gen/${op}_$PSET.txt" "fpga/tau/acvp/${op}_$PSET.txt"; then
      echo "VIRHE: fpga/tau/acvp/${op}_$PSET.txt ei vastaa NIST-lahteesta generoitua"
      FAILED=1
    fi
  done
fi

corrupt() {
  python3 - "$1" "$2" <<'PY'
import sys
lines = open(sys.argv[1]).read().split("\n")
i = max(k for k, l in enumerate(lines) if l.strip())
lines[i] = lines[i][:-1] + ("1" if lines[i][-1] == "0" else "0")
open(sys.argv[2], "w").write("\n".join(lines))
PY
}

# Vajaa tiedosto: ilmoitettu tapausmaara yhta suurempi kuin sisalto.
# Testipenkin TAYTYY epaonnistua (KORJAUSLISTA A12).
overclaim() {
  python3 - "$1" "$2" <<'PY'
import sys
lines = open(sys.argv[1]).read().split("\n")
lines[0] = str(int(lines[0]) + 1)
open(sys.argv[2], "w").write("\n".join(lines))
PY
}

# $1 = sim, $2 = vektorit, $3 = odotus (pass|fail), $4 = nimi
run_case() {
  local out result
  out="$(vvp "$1" +VEC="$2" 2>&1)"
  if echo "$out" | grep -q "^PASS" && ! echo "$out" | grep -q "FAIL"; then result=pass; else result=fail; fi
  if [ "$result" = "$3" ]; then
    echo "  ok    $4: $(echo "$out" | grep -E '^(PASS|FAIL)' | head -1)"
  else
    echo "  VIRHE $4: odotettu $3, saatu $result"
    echo "$out" | grep -E "EI TASMAA|FAIL|fatal" | head -5 | sed 's/^/        /'
    FAILED=1
  fi
}

echo "[1] Kaannetaan (K=$K)..."
OPS=(keygen encaps decaps)
for op in 0 1 2; do
  sim="sim/acvp_full_k${K}_op${op}"
  compile_tau "$sim" fpga/tau/mlkem_acvp_tb.sv -P mlkem_acvp_tb.K=$K -P mlkem_acvp_tb.OP=$op 2>&1 | grep -v sorry || true
  [ -f "$sim" ] || { echo "VIRHE: $sim ei kaantynyt"; exit 1; }
done

echo "[2] NIST ACVP ML-KEM-$PSET + negatiivikontrollit (rinnakkain)..."
for op in 0 1 2; do
  name="${OPS[$op]}"
  vec="fpga/tau/acvp/${name}_$PSET.txt"
  corrupt "$vec" "$TMP/${name}_bad.txt"
  run_case "sim/acvp_full_k${K}_op${op}" "$vec" pass "$name" > "$TMP/$name.log" &
  run_case "sim/acvp_full_k${K}_op${op}" "$TMP/${name}_bad.txt" fail "$name, turmeltu vektori" > "$TMP/${name}_bad.log" &
  overclaim "$vec" "$TMP/${name}_vajaa.txt"
  run_case "sim/acvp_full_k${K}_op${op}" "$TMP/${name}_vajaa.txt" fail "$name, vajaa tiedosto" > "$TMP/${name}_vajaa.log" &
done
wait
for name in "${OPS[@]}"; do
  cat "$TMP/$name.log" "$TMP/${name}_bad.log" "$TMP/${name}_vajaa.log"
  grep -q VIRHE "$TMP/$name.log" "$TMP/${name}_bad.log" "$TMP/${name}_vajaa.log" && FAILED=1
done

if [ "$FAILED" -ne 0 ]; then
  echo "ACVP ML-KEM-$PSET: VIRHEITA"
  exit 1
fi
echo "ACVP ML-KEM-$PSET: KeyGen 25, Encaps 25, Decaps 10; 6 negatiivikontrollia."
