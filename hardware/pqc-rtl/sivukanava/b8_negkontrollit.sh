#!/bin/bash
# B8-mittarin negatiivikontrollit: kolme tarkoituksella vuotavaa muunnelmaa
# pqc_mlkem_decaps_b1_core.sv:sta. Mittarin TAYTYY hylata kunkin kohdalla
# juuri se hypoteesi, jota vuoto rikkoo. Muuten mittari ei pysty
# havaitsemaan vuotoa, eika sen PATEE-tulos kerro mitaan.
#
#  L1 aikainen poistuminen: matchilla K_bar:ia ei lasketa  -> H1 hylataan
#  L2 salaisuusriippuva viive: z_in[0]=1 -> +1 sykli        -> H2 hylataan
#  L3 kaksoiskirjoitus: K_final_out <= K' aina, hylkayksessa
#     korvataan seuraavalla syklilla                         -> H4 hylataan
#
# Vain K=2 (nopeus). Kaytto: sivukanava/b8_negkontrollit.sh
set -uo pipefail
cd "$(dirname "$0")/.."
TMP="${B8_NEG_TMP:-$(mktemp -d)}"; [ -n "${B8_NEG_TMP:-}" ] || trap 'rm -rf "$TMP"' EXIT; mkdir -p "$TMP"
SRC=fpga/tau/pqc_mlkem_decaps_b1_core.sv
FAILED=0

python3 - "$SRC" "$TMP" <<'PY'
import sys
src, tmp = sys.argv[1], sys.argv[2]
s = open(src).read()

def variant(name, pairs):
    v = s
    for old, new in pairs:
        assert v.count(old) == 1, (name, old[:60])
        v = v.replace(old, new)
    open(f"{tmp}/{name}.sv", "w").write(v)

start = """        S_START_SHAKE256: begin
          shake256_msg_in[255:0] <= z_in;"""
wait_ = """        S_WAIT_SHAKE256: begin
          if (shake256_done) begin
            match_out <= (c_in === c_prime);
            K_final_out <= (c_in === c_prime) ? K_prime_in : shake256_out;
            state <= S_DONE;
          end
        end"""
done_ = """        S_DONE: begin
          done <= 1'b1;"""

variant("L1", [(start, """        S_START_SHAKE256: if (c_in === c_prime) begin
          match_out <= 1'b1; K_final_out <= K_prime_in; state <= S_DONE;
        end else begin
          shake256_msg_in[255:0] <= z_in;""")])
# L1: alkuperaisen haaran begin ... end -lohkon loppu-end paattaa else-haaran.

variant("L2", [(wait_, """        S_WAIT_SHAKE256: begin
          if (shake256_done || l2_viive) begin
            if (z_in[0] && !l2_viive) l2_viive <= 1'b1;
            else begin
              l2_viive <= 1'b0;
              match_out <= (c_in === c_prime);
              K_final_out <= (c_in === c_prime) ? K_prime_in : shake256_out;
              state <= S_DONE;
            end
          end
        end"""),
    ("  logic [8*C_BYTES-1:0] c_prime;\n", "  logic [8*C_BYTES-1:0] c_prime;\n  logic l2_viive = 1'b0;\n")])

variant("L3", [(wait_, """        S_WAIT_SHAKE256: begin
          if (shake256_done) begin
            match_out <= (c_in === c_prime);
            K_final_out <= K_prime_in;
            state <= S_DONE;
          end
        end"""),
    (done_, """        S_DONE: begin
          if (!match_out) K_final_out <= shake256_out;
          done <= 1'b1;""")])
PY
[ -f "$TMP/L3.sv" ] || { echo "VIRHE: muunnelmien luonti"; exit 1; }

check() {  # $1 = muunnelma, $2 = hypoteesi, jonka taytyy hylkaytya
  local out
  out="$(B8_KS=2 B8_B1_CORE="$TMP/$1.sv" bash run_b8_sivukanava.sh "$TMP/run_$1" 2>&1)"
  if echo "$out" | grep -q "^$2 .*HYLATAAN"; then
    echo "  ok    $1: $2 hylattiin ($(echo "$out" | grep "^$2 " | sed 's/^[^:]*: //'))"
  else
    echo "  VIRHE $1: $2 ei hylatty"; echo "$out" | grep -E "^H[0-9]|VIRHE|FAIL" | sed 's/^/        /'
    FAILED=1
  fi
}

echo "B8-negatiivikontrollit (K=2):"
check L1 H1 > "$TMP/L1.out" &
check L2 H2 > "$TMP/L2.out" &
check L3 H4 > "$TMP/L3.out" &
wait
cat "$TMP"/L1.out "$TMP"/L2.out "$TMP"/L3.out
if grep -q VIRHE "$TMP"/L*.out; then echo "B8-negatiivikontrollit: VIRHE"; exit 1; fi
echo "B8-negatiivikontrollit: kaikki kolme vuotoa havaittiin."
exit 0
