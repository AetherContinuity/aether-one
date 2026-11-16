#!/bin/bash
# B4-ENNAKKO.md H1: Yosysin FF-bitit moduulin omalla tasolla.
# Kaytto: b4/yosys_ff.ys.sh <moduuli> <K> <ulostulo.json>  (kirjoittaa .log ja .stat)
set -euo pipefail
cd "$(dirname "$0")/.."
source tau_common_files.sh
MOD="$1"; K="$2"; OUT="$3"
# K=3 on ytimien oletus. Yosys 0.33 kaatuu (Assert modules_.count) kun
# -chparam K yhdistyy alimoduulien uudelleenkasittelyyn, joten K=3:lla
# parametria ei aseteta.
CHP=""; [ "$K" = 3 ] || CHP="-chparam K $K"
yosys -q -l "${OUT%.json}.log" -p "
  read_verilog -sv -defer $TAU_RTL_FILES;
  hierarchy -top $MOD $CHP;
  proc; opt; memory -nomap; opt_clean;
  tee -o ${OUT%.json}.stat stat -width"
# FF-bitit: b4/ff_bitit.py <.stat> <moduuli>
