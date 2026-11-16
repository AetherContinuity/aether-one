#!/bin/bash
# B8: Decapsin ajoitus- ja toggle-otos, K=2 ja K=3 (sivukanava/B8-ENNAKKO.md).
#
# Kaytto: run_b8_sivukanava.sh [--vaadi] [ulostulohakemisto]
#   --vaadi: epaonnistuu, jos H1, H2 tai H4 hylataan (CI-regressio).
#   H5:n (oikeellisuus) pettaminen epaonnistuttaa aina.
# Lokit ja VCD:t: ulostulohakemisto (oletus: valiaikainen, poistetaan).
# Ymparistomuuttujat (negatiivikontrollit, sivukanava/b8_negkontrollit.sh):
#   B8_KS="2 3"       ajettavat K:t
#   B8_B1_CORE=<.sv>  korvaa pqc_mlkem_decaps_b1_core.sv:n kaannoksessa
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
KS="${B8_KS:-2 3}"
if [ -n "${B8_B1_CORE:-}" ]; then
  TAU_RTL_FILES="${TAU_RTL_FILES//fpga\/tau\/pqc_mlkem_decaps_b1_core.sv/$B8_B1_CORE}"
  echo "HUOM: decaps_b1_core korvattu: $B8_B1_CORE"
fi

echo "[1] Vektorit (golden-malli, NIST ACVP -avaimet)..."
for K in $KS; do
  P=$([ $K = 2 ] && echo 512 || echo 768)
  python3 sivukanava/gen_b8_vectors.py $P "$OUT/b8_$P.txt" || exit 1
done

echo "[2] Kaannos..."
for K in $KS; do
  compile_tau "$OUT/b8_k$K.vvp" sivukanava/b8_decaps_tb.sv -P b8_decaps_tb.K=$K 2>&1 | grep -v sorry || true
  [ -f "$OUT/b8_k$K.vvp" ] || { echo "VIRHE: $OUT/b8_k$K.vvp ei kaantynyt"; exit 1; }
done

echo "[3] Ajoitusajot (kaikki tapaukset) ja toggle-ajot (18) rinnakkain..."
mkdir -p "$OUT/toggle"
LOGS=""
for K in $KS; do
  P=$([ $K = 2 ] && echo 512 || echo 768)
  vvp "$OUT/b8_k$K.vvp" +VEC="$OUT/b8_$P.txt" > "$OUT/b8_k$K.log" 2>&1 &
  LOGS="$LOGS $OUT/b8_k$K.log"
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
    vvp "$OUT/b8_k$K.vvp" +VEC="$OUT/b8_$P.txt" +ONLY=$idx +VCD="$OUT/toggle/t_k${K}_${idx}_${tc}_${name}.vcd" \
      > "$OUT/toggle/t_k${K}_${idx}.log" 2>&1 &
  done < "$OUT/toggle_k$K.lst"
done
wait

for f in $LOGS "$OUT"/toggle/*.log; do
  grep -q "B8-AJO VALMIS" "$f" || { echo "VIRHE: $f"; tail -5 "$f"; exit 1; }
done

echo "[4] Arviointi (B8-ENNAKKO.md)..."
python3 sivukanava/b8_analyze.py "$OUT/toggle" $LOGS $VAADI
