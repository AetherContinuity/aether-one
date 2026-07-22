#!/usr/bin/env python3
"""count_toggles.py - Minimaalinen VCD-jasennin joka laskee arvon-
vaihtumien (kytkentojen) maaran per moduulihierarkia annetusta VCD-
tiedostosta.

M3-MLKEM-002-suunnitelman oma vaatimus: toggle-count-proxy-tyokalu
TAYTYY validoida tunnetusti vuotavalla leikkitoteutuksella ENNEN
kuin sen tulosta oikealle kohteelle (Decaps) voidaan tulkita
luotettavaksi. Tama skripti ON se mittari - EI viela sovellettu
Decapsiin, vain taman validointikokeen omaan leikkitoteutukseen.

Kaytto: count_toggles.py <vcd-tiedosto> <scope-prefiksi, esim. dut_leaky>
"""

import re
import sys
from collections import defaultdict


def parse_vcd(path, scope_filter):
    """Palauttaa (kokonaiskytkennat, per-signaali-kytkennat) annetun
    scope-prefiksin (esim. 'dut_leaky') alla oleville signaaleille."""

    id_to_name = {}
    in_scope_stack = []
    current_scope_path = []
    target_ids = set()

    with open(path) as f:
        lines = f.readlines()

    i = 0
    # --- Otsikko-osa: scope/var-maarittelyt ---
    while i < len(lines):
        line = lines[i].strip()
        if line.startswith("$scope"):
            parts = line.split()
            scope_name = parts[2] if len(parts) > 2 else ""
            current_scope_path.append(scope_name)
        elif line.startswith("$upscope"):
            if current_scope_path:
                current_scope_path.pop()
        elif line.startswith("$var"):
            # $var wire 8 ! signal_name [7:0] $end  (tai vastaava)
            m = re.match(r"\$var\s+\S+\s+\d+\s+(\S+)\s+(\S+)", line)
            if m:
                vcd_id, sig_name = m.group(1), m.group(2)
                id_to_name[vcd_id] = sig_name
                scope_str = ".".join(current_scope_path)
                if scope_filter in scope_str:
                    target_ids.add(vcd_id)
        elif line.startswith("$enddefinitions"):
            i += 1
            break
        i += 1

    # --- Data-osa: arvonvaihdot ---
    per_signal_toggles = defaultdict(int)
    total = 0

    for line in lines[i:]:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line[0] in "01xXzZ":
            # skalaari: <arvo><id>, esim. "1!"
            vcd_id = line[1:]
            if vcd_id in target_ids:
                per_signal_toggles[id_to_name[vcd_id]] += 1
                total += 1
        elif line[0] == "b":
            # vektori: "b<arvo> <id>"
            parts = line.split()
            if len(parts) == 2:
                vcd_id = parts[1]
                if vcd_id in target_ids:
                    per_signal_toggles[id_to_name[vcd_id]] += 1
                    total += 1

    return total, per_signal_toggles


def main():
    if len(sys.argv) != 3:
        print("Kaytto: count_toggles.py <vcd-tiedosto> <scope-prefiksi>")
        sys.exit(1)

    vcd_path, scope_filter = sys.argv[1], sys.argv[2]
    total, per_signal = parse_vcd(vcd_path, scope_filter)

    print(f"{vcd_path} (scope='{scope_filter}'): kokonaiskytkennat={total}")
    for name, count in sorted(per_signal.items(), key=lambda x: -x[1]):
        print(f"  {name}: {count}")


if __name__ == "__main__":
    main()
