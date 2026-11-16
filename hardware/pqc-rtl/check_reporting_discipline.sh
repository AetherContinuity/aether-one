#!/bin/bash
# Grep-tarkistus elaville referenssidokumenteille (ks. REPORTING-
# DISCIPLINE.md). EI tarkista historiallisia lokeja (DK*_STATUS.md,
# README.md:n narratiivikohdat) - vain nykytilaa kuvaavat dokumentit,
# joihin tulevat sessiot ankkuroituvat lahtooletuksena.
set -euo pipefail
cd "$(dirname "$0")"

LIVING_DOCS="dilithium-rtl/NIST_ACVP_STATUS.md M3_MLKEM_ACVP_STATUS.md FIPS203_COVERAGE.md ../../README.md ../../KORJAUSLISTA.md sivukanava/B8-TULOS.md"
BANNED_PATTERN='TAYDELLISESTI|erittain (vahva|hyva|merkittava)|🎉|riippumaton vahvistus|independent confirmation'

FAIL=0
for doc in $LIVING_DOCS; do
  if [ ! -f "$doc" ]; then echo "FAIL: $doc puuttuu"; FAIL=1; continue; fi
  if true; then
    if grep -inE "$BANNED_PATTERN" "$doc"; then
      echo "FAIL: $doc sisaltaa kielletyn ilmauksen (ks. REPORTING-DISCIPLINE.md)"
      FAIL=1
    fi
  fi
done

# Juuren README:n tilapaivays ei saa olla vanhempi kuin KORJAUSLISTA:n
# paivitys (README:n paivays oli 2026-10-02 viela 2026-11-16).
readme_d=$(grep -oE '^\*\*Tila päivitetty:\*\* [0-9]{4}-[0-9]{2}-[0-9]{2}' ../../README.md | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' || true)
lista_d=$(grep -oE '^\*\*Päivitetty:\*\* [0-9]{4}-[0-9]{2}-[0-9]{2}' ../../KORJAUSLISTA.md | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' || true)
if [ -z "$readme_d" ] || [ -z "$lista_d" ]; then
  echo "FAIL: README.md:n tai KORJAUSLISTA.md:n paivaysrivi puuttuu"; FAIL=1
elif [[ "$readme_d" < "$lista_d" ]]; then
  echo "FAIL: README.md tila $readme_d on vanhempi kuin KORJAUSLISTA.md $lista_d"; FAIL=1
fi

if [ "$FAIL" -eq 0 ]; then
  echo "PASS: elavat referenssidokumentit lapaisevat raportointikuritarkistuksen"
else
  exit 1
fi
