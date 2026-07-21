#!/usr/bin/env python3
"""M3-MLKEM: ACVP encapDecap-FIPS203 -> encaps_top_nist_vector.txt.
Itsetarkistus: puretut kentat verrataan ML-KEM-512:n tunnettuihin
tavupituuksiin ENNEN kirjoitusta, jotta jarjestysvirhe (kuten
(K,c) vs. (c,K) taman skriptin ensimmaisessa versiossa - ks.
kayttajan oma huomio 2026-07-21) ei paase lapi hiljaa.

HUOM: K ja m ovat molemmat 32 tavua - pituustarkistus EI erota
naita toisistaan, mutta nappaa kaikki MUUT sekaannukset (esim. ek/c
-vaihdon, joilla on eri pituudet: 800 vs. 768)."""

import json
import sys

EK_LEN = 800
C_LEN = 768
K_LEN = 32
M_LEN = 32

def pack_bytes(b):
    v = 0
    for i, byte in enumerate(b):
        v |= byte << (i * 8)
    return v

def main(tc_id=1):
    with open('/home/claude/acvp-server/gen-val/json-files/'
              'ML-KEM-encapDecap-FIPS203/internalProjection.json') as f:
        d = json.load(f)

    for tg in d['testGroups']:
        if tg['tgId'] == 1:  # ML-KEM-512, encapsulation
            for t in tg['tests']:
                if t['tcId'] == tc_id:
                    ek = bytes.fromhex(t['ek'])
                    m = bytes.fromhex(t['m'])
                    c_expect = bytes.fromhex(t['c'])
                    k_expect = bytes.fromhex(t['k'])
                    break
            break

    # Itsetarkistus ENNEN kirjoitusta
    assert len(ek) == EK_LEN, f"ek pituus {len(ek)} != {EK_LEN} - todennakoinen kenttasekaannus"
    assert len(c_expect) == C_LEN, f"c pituus {len(c_expect)} != {C_LEN} - todennakoinen kenttasekaannus"
    assert len(k_expect) == K_LEN, f"k pituus {len(k_expect)} != {K_LEN} - todennakoinen kenttasekaannus"
    assert len(m) == M_LEN, f"m pituus {len(m)} != {M_LEN} - todennakoinen kenttasekaannus"

    with open("fpga/tau/encaps_top_nist_vector.txt", "w") as f:
        f.write(f"{pack_bytes(ek):0{EK_LEN*2}x}\n")
        f.write(f"{pack_bytes(m):0{M_LEN*2}x}\n")
        f.write(f"{pack_bytes(k_expect):0{K_LEN*2}x}\n")
        f.write(f"{pack_bytes(c_expect):0{C_LEN*2}x}\n")
    print(f"Kirjoitettu (tgId=1, tcId={tc_id}) - pituustarkistus lapaisi")

if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else 1)
