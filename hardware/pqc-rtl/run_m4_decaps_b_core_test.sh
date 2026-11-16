#!/bin/bash
# Decaps Phase B -ytimen (pqc_mlkem_decaps_b1_core) vaihekohtaiset testit,
# K=2: B1-B3 valivaiheet golden-malliin (pqc_mlkem_decaps_b1_core_tb) ja
# FO-valinta kolmella tapauksella (pqc_mlkem_decaps_b4_allcases_tb).
#
# KORJAUSLISTA A11: nama epaonnistuivat ajettaessa ilman taman skriptin
# generointivaihetta, koska vectors/mlkem_decaps_b_vectors.txt on
# generoitu (gitignore) eika testipenkki tarkistanut tiedoston avautumista.
set -euo pipefail
cd "$(dirname "$0")"
source tau_common_files.sh
mkdir -p sim

python3 m2-golden/gen_full_ntt_vectors.py > /dev/null
python3 m2-golden/gen_ntt_inverse_schedule.py > /dev/null
python3 m2-golden/gen_mlkem_decaps_b_vectors.py

for tb in pqc_mlkem_decaps_b1_core_tb pqc_mlkem_decaps_b4_allcases_tb; do
  compile_tau sim/$tb fpga/tau/$tb.sv
  vvp sim/$tb
done
