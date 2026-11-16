#!/usr/bin/env python3
"""FF-bitit Yosysin 'stat -width' -tulosteesta yhden moduulin omalta tasolta.
Kaytto: b4/ff_bitit.py <.stat> <moduuli>
Laskee $*dff*_N- ja $*dlatch*_N-solut: bitit = N x solumaara.
$mem_v2-solut raportoidaan erikseen (leveys ei nay statissa)."""
import re, sys
path, mod = sys.argv[1], sys.argv[2]
txt = open(path).read()
m = re.search(r"=== " + re.escape(mod) + r" ===\n(.*?)(?:\n=== |\Z)", txt, re.S)
if not m:
    sys.exit(f"moduulia {mod} ei loydy")
tot, mem = 0, 0
for l in m.group(1).splitlines():
    f = re.match(r"\s+\$\w*(?:dff|dlatch)\w*_(\d+)\s+(\d+)", l)
    if f:
        tot += int(f.group(1)) * int(f.group(2))
    g = re.match(r"\s+\$mem_v2\s+(\d+)", l)
    if g:
        mem += int(g.group(1))
print(f"{mod}: FF-bitteja {tot}; $mem_v2-soluja {mem} (ei laskettu)")
