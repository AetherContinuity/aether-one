#!/usr/bin/env python3
"""B8-otoksen arviointi B8-ENNAKKO.md:n hylkayssaantojen mukaan.

Kaytto: b8_analyze.py <K=2-ajon loki> <K=3-ajon loki> <toggle-hakemisto> [--vaadi]

Toggle-hakemistossa: t_k<K>_<tapausindeksi>_<tcId>_<muunnelma>.vcd.
Palautusarvo: 2, jos H5 (oikeellisuus) ei pade. --vaadi: 1, jos H1, H2
tai H4 hylataan (CI-regressiokaytto). Muuten 0."""
import glob
import os
import re
import sys
from collections import defaultdict

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "toggle-proxy"))
from count_toggles import parse_vcd  # noqa: E402

NAMES = ["V", "R0", "R1", "R2", "R3", "RN", "SWAP"]


def read_log(path, K):
    rows = []
    for line in open(path):
        if line.startswith("B8 "):
            tc, vid, pa, pb, tot, kok, m, mexp = map(int, line.split()[1:])
            rows.append(dict(K=K, tc=tc, vid=vid, pa=pa, pb=pb, tot=tot, kok=kok, m=m, mexp=mexp))
        if line.startswith("FAIL"):
            sys.exit(f"{path}: {line.strip()}")
    return rows


def main(log2, log3, tdir, vaadi):
    rows = read_log(log2, 2) + read_log(log3, 3)
    print(f"Ajoja: {len(rows)} (K=2: {sum(r['K'] == 2 for r in rows)}, K=3: {sum(r['K'] == 3 for r in rows)})")

    h5 = [r for r in rows if r["kok"] != 1 or r["m"] != r["mexp"] or
          (r["vid"] == 0 and r["m"] != 1) or (1 <= r["vid"] <= 5 and r["m"] != 0)]
    print(f"H5 oikeellisuus: {'PATEE' if not h5 else 'EI PADE'} ({len(rows) - len(h5)}/{len(rows)})")
    for r in h5:
        print(f"   EI PADE: K={r['K']} tcId={r['tc']} {NAMES[r['vid']]} K_ok={r['kok']} match={r['m']}/{r['mexp']}")
    if h5:
        print("H5 ei pade: H1-H4 jatetaan tulkitsematta (ennakkorekisteroinnin mukaan).")
        return 2

    by_key = defaultdict(dict)
    for r in rows:
        by_key[(r["K"], r["tc"])][r["vid"]] = (r["pa"], r["pb"], r["tot"])

    h1_fail, h2_fail = [], []
    n1 = n2 = 0
    for key, v in sorted(by_key.items()):
        ref = v[0]
        for vid, t in v.items():
            if vid in (1, 2, 3, 4, 5):
                n1 += 1
                if t != ref:
                    h1_fail.append((key, NAMES[vid], ref, t))
            if vid == 6:
                n2 += 1
                if t != ref:
                    h2_fail.append((key, ref, t))
    print(f"H1 syklit, c:n muunnelmat vs V: {'PATEE' if not h1_fail else 'HYLATAAN'} ({n1 - len(h1_fail)}/{n1} vertailua)")
    for f in h1_fail:
        print(f"   ERO: K={f[0][0]} tcId={f[0][1]} {f[1]}: V={f[2]} muunnelma={f[3]}")
    print(f"H2 syklit, vaihdettu salaisuus vs V: {'PATEE' if not h2_fail else 'HYLATAAN'} ({n2 - len(h2_fail)}/{n2} vertailua)")
    for f in h2_fail:
        print(f"   ERO: K={f[0][0]} tcId={f[0][1]}: V={f[1]} SWAP={f[2]}")

    print("Avainkohtaiset syklit (V; Phase A, Phase B, kokonais):")
    for K in (2, 3):
        vals = [(tc, by_key[(K, tc)][0]) for (k, tc) in sorted(by_key) if k == K]
        pa = sorted({t[0] for _, t in vals}); pb = sorted({t[1] for _, t in vals}); tot = sorted({t[2] for _, t in vals})
        print(f"   K={K}: Phase A {pa[0]}..{pa[-1]} ({len(pa)} eri), Phase B {pb[0]}..{pb[-1]} ({len(pb)} eri), "
              f"kokonais {tot[0]}..{tot[-1]} ({len(tot)} eri)")

    h4_fail, n4 = [], 0
    for vcd in sorted(glob.glob(os.path.join(tdir, "t_k*.vcd"))):
        m = re.match(r"t_k(\d)_(\d+)_(\d+)_(\w+)\.vcd", os.path.basename(vcd))
        K, _idx, tc, name = int(m.group(1)), m.group(2), int(m.group(3)), m.group(4)
        _t, bits, _e = parse_vcd(vcd, "decaps_b", {"clk", "reset", "start", "a_in", "b_in"})
        cand = "K_prime_in" if name == "V" else "shake256_out"
        diff = bits.get("K_final_out", 0) - bits.get(cand, 0)
        n4 += 1
        print(f"   toggle K={K} tcId={tc} {name}: K_final_out={bits.get('K_final_out', 0)} "
              f"{cand}={bits.get(cand, 0)} ero={diff}")
        if diff != 0:
            h4_fail.append(vcd)
    if n4 != 18:
        print(f"H4: odotettiin 18 VCD-ajoa, loytyi {n4}")
        h4_fail.append("maara")
    print(f"H4 toggle, K_final_out = valittu ehdokas: {'PATEE' if not h4_fail else 'HYLATAAN'} ({n4} ajoa)")

    if vaadi and (h1_fail or h2_fail or h4_fail):
        return 1
    return 0


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--vaadi"]
    if len(args) != 3:
        sys.exit(__doc__)
    sys.exit(main(*args, vaadi="--vaadi" in sys.argv))
