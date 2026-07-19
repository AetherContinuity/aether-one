#!/bin/bash
# UNIT-tason testit: yksittainen moduuli, minimaaliset riippuvuudet.
# Taso: Unit (ks. TESTING.md). Ajetaan joka pushilla.
set -euo pipefail
cd "$(dirname "$0")"

run_test() {
  local name="$1"
  shift
  echo "--- $name ---"
  iverilog -g2012 -o "sim/unit_$name" "$@"
  vvp "sim/unit_$name"
}

run_test "make_hint" \
  dilithium-rtl/pqc_dilithium_decompose.sv dilithium-rtl/pqc_dilithium_make_hint.sv \
  dilithium-rtl/pqc_dilithium_make_hint_tb.sv

run_test "pack_z" dilithium-rtl/pqc_dilithium_pack_z.sv dilithium-rtl/pqc_dilithium_pack_z_tb.sv

run_test "pack_h" dilithium-rtl/pqc_dilithium_pack_h.sv dilithium-rtl/pqc_dilithium_pack_h_tb.sv

echo "=================================================="
echo "PASS: kaikki UNIT-tason Sign-primitiivitestit lapaisivat"
echo "=================================================="
