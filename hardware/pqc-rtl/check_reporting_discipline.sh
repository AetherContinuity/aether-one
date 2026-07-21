#!/bin/bash
# Grep-tarkistus elaville referenssidokumenteille (ks. REPORTING-
# DISCIPLINE.md). EI tarkista historiallisia lokeja (DK*_STATUS.md,
# README.md:n narratiivikohdat) - vain nykytilaa kuvaavat dokumentit,
# joihin tulevat sessiot ankkuroituvat lahtooletuksena.
set -euo pipefail
cd "$(dirname "$0")"

LIVING_DOCS="dilithium-rtl/NIST_ACVP_STATUS.md M3_MLKEM_ACVP_STATUS.md FIPS203_COVERAGE.md"
BANNED_PATTERN='TAYDELLISESTI|erittain (vahva|hyva|merkittava)|🎉|riippumaton vahvistus|independent confirmation'

FAIL=0
for doc in $LIVING_DOCS; do
  if [ -f "$doc" ]; then
    if grep -inE "$BANNED_PATTERN" "$doc"; then
      echo "FAIL: $doc sisaltaa kielletyn ilmauksen (ks. REPORTING-DISCIPLINE.md)"
      FAIL=1
    fi
  fi
done

if [ "$FAIL" -eq 0 ]; then
  echo "PASS: elavat referenssidokumentit lapaisevat raportointikuritarkistuksen"
else
  exit 1
fi
