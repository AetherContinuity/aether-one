#!/usr/bin/env python3
"""M3 stabilization: varmista etta FIPS203_COVERAGE.md mainitsee
kaikki odotetut FIPS 203 -algoritminumerot. Ei taydellinen ratkaisu
(kayttajan oma huomio), mutta estaa dokumentaation hiljaisen
vanhenemisen."""

import re
import sys

EXPECTED_ALGORITHM_NUMBERS = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16, 17, 18, 19, 20, 21]

import os
script_dir = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(script_dir, "FIPS203_COVERAGE.md")) as f:
    content = f.read()

# Poimi kaikki taulukon "| N |" -muotoiset algoritminumerot
found_numbers = set()
for line in content.split("\n"):
    m = re.match(r"\|\s*(\d+)\s*\|", line)
    if m:
        found_numbers.add(int(m.group(1)))

missing = [n for n in EXPECTED_ALGORITHM_NUMBERS if n not in found_numbers]

if missing:
    print(f"FAIL: FIPS203_COVERAGE.md ei mainitse algoritmeja: {missing}")
    sys.exit(1)
else:
    print(f"OK: kaikki {len(EXPECTED_ALGORITHM_NUMBERS)} odotettua algoritminumeroa loytyvat FIPS203_COVERAGE.md:sta")
