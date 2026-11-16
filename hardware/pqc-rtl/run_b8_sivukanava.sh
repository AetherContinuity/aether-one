#!/bin/bash
# B8: Decapsin ajoitus- ja toggle-otos, K=2 ja K=3 (sivukanava/B8-ENNAKKO.md).
#
# Kaytto: run_b8_sivukanava.sh [--vaadi] [ulostulohakemisto]
#   --vaadi: epaonnistuu, jos H1, H2 tai H4 hylataan (CI-regressio).
#   H5:n (oikeellisuus) pettaminen epaonnistuttaa aina.
# Lokit ja VCD:t: ulostulohakemisto (oletus: valiaikainen, poistetaan).
set -uo pipefail
cd "$(dirname "$0")"
source tau_common_files.sh
mkdir -p sim

VAADI=""
OUT=""
for a in "$@"; do
  case "$a" in
    --vaadi) VAADI="--vaadi" ;;
    *) OUT="$a" ;;
  esac
done
if [ -z "$OUT" ]; then OUT="$(mktemp -d)"; trap 'rm -rf "$OUT"' EXIT; fi
mkdir -p "$OUT"

echo "[1] Vektorit (golden-malli, NIST ACVP -avaimet)..."
python3 sivukanava/gen_b8_vectors.py 512 "$OUT/b8_512.txt" || exit 1
python3 sivukanava/gen_b8_vectors.py 768 "$OUT/b8_768.txt" || exit 1

echo "[2] Kaannos..."
for K in 2 3; do
  compile_tau sim/b8_k$K sivukanava/b8_decaps_tb.sv -P b8_decaps_tb.K=$K 2>&1 | grep -v sorry || true
  [ -f sim/b8_k$K ] || { echo "VIRHE: sim/b8_k$K ei kaantynyt"; exit 1; }
done

echo "[3] Ajoitusajot (kaikki tapaukset) ja toggle-ajot (18) rinnakkain..."
vvp sim/b8_k2 +VEC="$OUT/b8_512.txt" > "$OUT/b8_k2.log" 2>&1 &
vvp sim/b8_k3 +VEC="$OUT/b8_768.txt" > "$OUT/b8_k3.log" 2>&1 &
mkdir -p "$OUT/toggle"
for K in 2 3; do
  P=$([ $K = 2 ] && echo 512 || echo 768)
  # 3 ensimmaista avainta x (V, R0, R3) = muunnelmat 0, 1, 4
  python3 - "$OUT/b8_$P.txt" <<'PY' > "$OUT/toggle_k$K.lst"
import sys
lines = [l.strip() for l in open(sys.argv[1]) if l.strip()]
n = int(lines[0]); keys = []
names = ["V", "R0", "R1", "R2", "R3", "RN", "SWAP"]
for i in range(n):
    tc, vid, _m = map(int, lines[1 + 4 * i].split())
    if tc not in keys: keys.append(tc)
    if tc in keys[:3] and vid in (0, 1, 4):
        print(i, tc, names[vid])
PY
  while read -r idx tc name; do
    vvp sim/b8_k$K +VEC="$OUT/b8_$P.txt" +ONLY=$idx +VCD="$OUT/toggle/t_k${K}_${idx}_${tc}_${name}.vcd" \
      > "$OUT/toggle/t_k${K}_${idx}.log" 2>&1 &
  done < "$OUT/toggle_k$K.lst"
done
wait

for f in "$OUT"/b8_k2.log "$OUT"/b8_k3.log "$OUT"/toggle/*.log; do
  grep -q "B8-AJO VALMIS" "$f" || { echo "VIRHE: $f"; tail -5 "$f"; exit 1; }
done

echo "[4] Arviointi (B8-ENNAKKO.md)..."
python3 sivukanava/b8_analyze.py "$OUT/b8_k2.log" "$OUT/b8_k3.log" "$OUT/toggle" $VAADI
