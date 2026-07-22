#!/usr/bin/env python3
"""count_toggles.py - VCD-jasennin joka laskee BITTITASON kytkentojen
(Hamming-etaisyys perakkaisten arvojen valilla) maaran per moduuli-
hierarkia annetusta VCD-tiedostosta.

KORJATTU 2026-07-22 (loydetty ennen Decaps-tuloksen tulkintaa):
ALKUPERAINEN versio laski "arvo vaihtui" -TAPAHTUMIA (yksi VCD-rivi =
yksi tapahtuma), EI bittitason kytkentoja. Tama on METODOLOGISESTI
TYHJA leveille signaaleille (esim. 256-bittinen K_final_out) - "arvo
vaihtui" -tapahtumien maara on SAMA riippumatta siita OVATKO kaksi
eri 256-bittista arvoa (K_prime vs K_bar) lahella toisiaan vai
taysin erilaisia. Todellinen tehonkulutukseen korreloiva suure on
BITTIEN MAARA jotka vaihtavat tilaa (Hamming-etaisyys), EI arvon-
vaihtotapahtumien lukumaara.

M3-MLKEM-002-suunnitelman oma vaatimus: toggle-count-proxy-tyokalu
TAYTYY validoida tunnetusti vuotavalla leikkitoteutuksella ENNEN
kuin sen tulosta oikealle kohteelle (Decaps) voidaan tulkita
luotettavaksi. Tama skripti ON se mittari.

Kaytto: count_toggles.py <vcd-tiedosto> <scope-prefiksi, esim. dut_leaky>
"""

import re
import sys
from collections import defaultdict


def parse_value(val_str):
    """Muuntaa VCD-arvomerkkijonon kokonaisluvuksi. x/z-bitit
    kasitellaan 0:na (approksimaatio - ei taydellinen mutta riittava
    tahan tarkoitukseen, koska x/z EI PITAISI esiintya normaalin
    simuloinnin aikana reset:in jalkeen)."""
    return int(val_str.replace('x', '0').replace('z', '0'), 2) if val_str else 0


def parse_vcd(path, scope_filter):
    """Palauttaa (kokonais_bittikytkennat, per-signaali-bittikytkennat)
    annetun scope-prefiksin alla oleville signaaleille."""

    id_to_name = {}
    id_to_width = {}
    current_scope_path = []
    target_ids = set()

    with open(path) as f:
        lines = f.readlines()

    i = 0
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
            m = re.match(r"\$var\s+\S+\s+(\d+)\s+(\S+)\s+(\S+)", line)
            if m:
                width, vcd_id, sig_name = int(m.group(1)), m.group(2), m.group(3)
                id_to_name[vcd_id] = sig_name
                id_to_width[vcd_id] = width
                scope_str = ".".join(current_scope_path)
                if scope_filter in scope_str:
                    target_ids.add(vcd_id)
        elif line.startswith("$enddefinitions"):
            i += 1
            break
        i += 1

    per_signal_bit_toggles = defaultdict(int)
    per_signal_event_count = defaultdict(int)
    last_value = {}
    total_bit_toggles = 0

    for line in lines[i:]:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line[0] in "01xXzZ":
            vcd_id = line[1:]
            if vcd_id in target_ids:
                new_val = 1 if line[0] == '1' else 0
                old_val = last_value.get(vcd_id, 0)
                if new_val != old_val:
                    per_signal_bit_toggles[id_to_name[vcd_id]] += 1
                    total_bit_toggles += 1
                per_signal_event_count[id_to_name[vcd_id]] += 1
                last_value[vcd_id] = new_val
        elif line[0] == "b":
            parts = line.split()
            if len(parts) == 2:
                val_str, vcd_id = parts[0][1:], parts[1]
                if vcd_id in target_ids:
                    new_val = parse_value(val_str)
                    old_val = last_value.get(vcd_id, 0)
                    hamming = bin(new_val ^ old_val).count('1')
                    per_signal_bit_toggles[id_to_name[vcd_id]] += hamming
                    total_bit_toggles += hamming
                    per_signal_event_count[id_to_name[vcd_id]] += 1
                    last_value[vcd_id] = new_val

    return total_bit_toggles, per_signal_bit_toggles, per_signal_event_count


def main():
    if len(sys.argv) != 3:
        print("Kaytto: count_toggles.py <vcd-tiedosto> <scope-prefiksi>")
        sys.exit(1)

    vcd_path, scope_filter = sys.argv[1], sys.argv[2]
    total, per_signal_bits, per_signal_events = parse_vcd(vcd_path, scope_filter)

    print(f"{vcd_path} (scope='{scope_filter}'): kokonais_bittikytkennat={total}")
    for name, bits in sorted(per_signal_bits.items(), key=lambda x: -x[1])[:30]:
        events = per_signal_events[name]
        print(f"  {name}: {bits} bittikytkentaa ({events} tapahtumaa, ~{bits/events:.1f} bittia/tapahtuma)")


if __name__ == "__main__":
    main()


if __name__ == "__main__":
    main()
