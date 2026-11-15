#!/usr/bin/env python3
"""NIST ACVP (FIPS 203) -> RTL-testipenkkien vektoritiedostot, mika
tahansa ML-KEM-parametrisarja.

Kaytto:
  gen_mlkem_acvp_vectors.py <ML-KEM-512|ML-KEM-768> <keyGen.json> \
      <encapDecap.json> <ulostulohakemisto>

Kirjoittaa kolme tiedostoa (<sarja> = 512 tai 768):
  keygen_<sarja>.txt   N; per tapaus: "tcId", d, z, ek, dk
  encaps_<sarja>.txt   N; per tapaus: "tcId", ek, m, K, c
  decaps_<sarja>.txt   N; per tapaus: "tcId hylkays", dk, c, K
                       (sama muoto kuin fpga/tau/decaps_top_nist_vectors.txt)

Heksaluvut ovat little-endian pakattuja (tavu 0 = vahiten merkitseva),
kuten muissakin taman kansion vektoreissa.

Jokainen tapaus ajetaan ENNEN kirjoitusta myos golden-mallin lapi
(mlkem_golden.py). Jos golden-malli ja NIST eroavat, skripti
keskeytyy: silloin vika on mallissa tai kenttien tulkinnassa, eika
RTL-vertailu kertoisi mitaan. Kenttien pituudet tarkistetaan
parametrisarjan mukaan (ek/c-sekaannus nakyy pituuserona)."""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mlkem_golden import (mlkem_keygen_internal, mlkem_encaps_internal,
                          mlkem_decaps_internal)

# FIPS 203, taulukko 2
PARAMS = {
    "ML-KEM-512": dict(K=2, ETA1=3, ETA2=2, DU=10, DV=4),
    "ML-KEM-768": dict(K=3, ETA1=2, ETA2=2, DU=10, DV=4),
}


def lengths(p):
    k = p["K"]
    return dict(ek=384 * k + 32, dk=768 * k + 96,
                c=32 * (p["DU"] * k + p["DV"]), K=32, m=32, d=32, z=32)


def pack(b):
    return f"{int.from_bytes(b, 'little'):0{len(b) * 2}x}"


def check_len(name, b, L, tc):
    if len(b) != L[name]:
        sys.exit(f"tcId={tc}: {name} pituus {len(b)} != {L[name]}")


def main(pset, kg_path, ed_path, outdir):
    p = PARAMS[pset]
    L = lengths(p)
    K, E1, E2, DU, DV = p["K"], p["ETA1"], p["ETA2"], p["DU"], p["DV"]
    suffix = pset.split("-")[-1]
    kg = json.load(open(kg_path))
    ed = json.load(open(ed_path))

    rows = []
    for g in kg["testGroups"]:
        if g["parameterSet"] != pset:
            continue
        for t in g["tests"]:
            tc = t["tcId"]
            d, z = bytes.fromhex(t["d"]), bytes.fromhex(t["z"])
            ek, dk = bytes.fromhex(t["ek"]), bytes.fromhex(t["dk"])
            for n, b in (("d", d), ("z", z), ("ek", ek), ("dk", dk)):
                check_len(n, b, L, tc)
            if mlkem_keygen_internal(d, z, K, E1) != (ek, dk):
                sys.exit(f"KeyGen tcId={tc}: golden-malli != NIST")
            rows.append(f"{tc}\n{pack(d)}\n{pack(z)}\n{pack(ek)}\n{pack(dk)}\n")
    write(outdir, f"keygen_{suffix}.txt", rows)

    enc, dec = [], []
    for g in ed["testGroups"]:
        if g["parameterSet"] != pset:
            continue
        for t in g["tests"]:
            tc = t["tcId"]
            if g["function"] == "encapsulation":
                ek, m = bytes.fromhex(t["ek"]), bytes.fromhex(t["m"])
                k, c = bytes.fromhex(t["k"]), bytes.fromhex(t["c"])
                for n, b in (("ek", ek), ("m", m), ("K", k), ("c", c)):
                    check_len(n, b, L, tc)
                if mlkem_encaps_internal(ek, m, K, E1, E2, DU, DV) != (k, c):
                    sys.exit(f"Encaps tcId={tc}: golden-malli != NIST")
                enc.append(f"{tc}\n{pack(ek)}\n{pack(m)}\n{pack(k)}\n{pack(c)}\n")
            elif g["function"] == "decapsulation":
                dk, c, k = (bytes.fromhex(t[x]) for x in ("dk", "c", "k"))
                for n, b in (("dk", dk), ("c", c), ("K", k)):
                    check_len(n, b, L, tc)
                if mlkem_decaps_internal(dk, c, K, E1, E2, DU, DV) != k:
                    sys.exit(f"Decaps tcId={tc}: golden-malli != NIST")
                rej = 0 if t["reason"] == "valid decapsulation" else 1
                dec.append(f"{tc} {rej}\n{pack(dk)}\n{pack(c)}\n{pack(k)}\n")
    write(outdir, f"encaps_{suffix}.txt", enc)
    write(outdir, f"decaps_{suffix}.txt", dec)


def write(outdir, name, rows):
    if not rows:
        sys.exit(f"{name}: ei yhtaan tapausta")
    path = os.path.join(outdir, name)
    with open(path, "w") as f:
        f.write(f"{len(rows)}\n")
        f.writelines(rows)
    print(f"{path}: {len(rows)} tapausta, golden-malli = NIST kaikissa")


if __name__ == "__main__":
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    main(*sys.argv[1:])
