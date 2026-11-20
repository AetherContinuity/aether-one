#!/usr/bin/env python3
"""K7: oma KeyDescription-jäsennin vs. Googlen jäsennin samoilla varmenteilla.

  layout OUT GOOGLE_REPO AUDITOR_REPO   # kokoaa ketjut OUT/<nimi>/c<i>.der + synteettiset
  ours OUT > ours.jsonl                  # oma jäsennin
  compare ours.jsonl google.jsonl        # ero -> exit 1
  selftest ours.jsonl google.jsonl       # vertailijan negatiivikontrolli: muutettu arvo kaatuu

Lähteet kiinnitetty: google/android-key-attestation f9846cd,
dbaxa/AttestationSamples b7f2d29. Tiedostojen sha256-kooste tulostetaan ja
verrataan arvoon SOURCES_SHA256 (muuttunut lähde kaataa).

Päivämäärien vertailusääntö: Googlen jäsennin normalisoi osPatchLevel muotoon
yyyyMM ja vendor/bootPatchLevel muotoon LocalDate (kuukausi 00 -> 01, päivä
00 tai puuttuva -> 01). Vertailu: vuosi ja kuukausi aina; päivä vain kun oma
raaka-arvo on 8-numeroinen ja päivä ≠ 00. Kuukausi 00 kirjataan erikseen.
"""

from __future__ import annotations

import hashlib
import json
import re
import shutil
import sys
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
sys.path.insert(0, str(HERE))

from core.trustcore.android_chain import parse_cert  # noqa: E402
from core.trustcore.android_kd import KEY_DESCRIPTION_OID, parse_key_description  # noqa: E402

SOURCES_SHA256 = "afe323be76df6538daa11afb891c58a0d55170afe177120c878aa54eb97b9d63"  # f9846cd + b7f2d29


def layout(out: Path, google: Path, auditor: Path) -> None:
    if out.exists():
        shutil.rmtree(out)
    files = sorted(google.glob("src/test/resources/der/*/cert*.der")) + sorted(auditor.glob("*/*cert-*.der.x509"))
    h = hashlib.sha256()
    for f in files:
        h.update(f.relative_to(f.parents[1]).as_posix().encode())
        h.update(f.read_bytes())
    digest = h.hexdigest()
    print(f"lähteiden sha256: {digest} ({len(files)} tiedostoa)", file=sys.stderr)
    if digest != SOURCES_SHA256:
        raise SystemExit(f"lähdetiedostot muuttuneet: {digest} ≠ {SOURCES_SHA256}")
    groups = defaultdict(list)
    for f in files:
        m = re.match(r"(.*?)(\d+)\.der", f.name)
        src = "google" if google in f.parents else "auditor"
        name = f"{src}_{f.parent.name}_{m.group(1)}".replace(" ", "_").replace("-", "_").rstrip("_")
        groups[name].append((int(m.group(2)), f))
    for name, lst in groups.items():
        d = out / name
        d.mkdir(parents=True)
        for i, (_, f) in enumerate(sorted(lst)):
            (d / f"c{i}.der").write_bytes(f.read_bytes())
    from synth import reference_set
    reference_set(out)


def _rec(kd: dict) -> dict:
    def al(a):
        rot = a["rootOfTrust"]
        return {"purpose": sorted(a["purpose"]), "algorithm": a["algorithm"],
                "rootOfTrust": None if rot is None else {k: rot[k] for k in
                                                         ("verifiedBootKey", "deviceLocked", "verifiedBootState", "verifiedBootHash")},
                "osVersion": a["osVersion"], "osPatchLevel": a["osPatchLevel"],
                "vendorPatchLevel": a["vendorPatchLevel"], "bootPatchLevel": a["bootPatchLevel"]}
    return {"attestationVersion": kd["attestationVersion"],
            "attestationSecurityLevel": kd["attestationSecurityLevel"],
            "keymasterVersion": kd["keyMintVersion"], "keymasterSecurityLevel": kd["keyMintSecurityLevel"],
            "attestationChallenge": kd["attestationChallenge"],
            "softwareEnforced": al(kd["softwareEnforced"]), "teeEnforced": al(kd["hardwareEnforced"])}


def ours(out: Path) -> None:
    for d in sorted(p for p in out.iterdir() if p.is_dir()):
        for f in sorted(d.glob("c*.der"), key=lambda p: int(p.stem[1:])):
            c = parse_cert(f.read_bytes())
            v = c.extensions.get(KEY_DESCRIPTION_OID)
            if v is None:
                continue
            try:
                rec = _rec(parse_key_description(v))
            except Exception as e:
                rec = {"error": str(e)}
            print(json.dumps({"chain": d.name, "index": int(f.stem[1:]), **rec}, sort_keys=True))


def _date_eq(field: str, mine, theirs) -> bool:
    if mine is None or theirs is None:
        return mine is None and theirs is None
    s = str(mine)
    t = str(theirs)
    if field == "osPatchLevel":
        return len(s) == 6 and s == t
    if len(s) not in (6, 8) or len(t) != 8:
        return False
    if s[:4] != t[:4] or (max(int(s[4:6]), 1) != int(t[4:6])):
        return False
    if len(s) == 8 and s[6:8] != "00":
        return s[6:8] == t[6:8]
    return True


def _diff(a: dict, b: dict, path="") -> list:
    out = []
    for k in sorted(set(a) | set(b)):
        p = f"{path}.{k}" if path else k
        x, y = a.get(k), b.get(k)
        if k in ("osPatchLevel", "vendorPatchLevel", "bootPatchLevel"):
            if not _date_eq(k, x, y):
                out.append(f"{p}: oma {x} ≠ google {y}")
        elif isinstance(x, dict) and isinstance(y, dict):
            out += _diff(x, y, p)
        elif x != y:
            out.append(f"{p}: oma {x!r} ≠ google {y!r}")
    return out


def load(p: str) -> dict:
    d = {}
    for line in open(p, encoding="utf-8"):
        if line.strip():
            r = json.loads(line)
            d[(r.pop("chain"), r.pop("index"))] = r
    return d


def compare(mine: dict, google: dict, quiet=False) -> int:
    diffs = []
    for key in sorted(set(mine) | set(google)):
        if key not in mine or key not in google:
            diffs.append(f"{key}: vain {'omassa' if key in mine else 'Googlen'} tulosteessa")
            continue
        diffs += [f"{key}: {d}" for d in _diff(mine[key], google[key])]
    if not quiet:
        print(f"{len(mine)} tietuetta omasta, {len(google)} Googlen jäsentimestä, eroja {len(diffs)}")
        for d in diffs[:50]:
            print("  ", d)
    return 1 if diffs else 0


def main(a: list) -> int:
    if a[0] == "layout":
        layout(Path(a[1]), Path(a[2]), Path(a[3]))
        return 0
    if a[0] == "ours":
        ours(Path(a[1]))
        return 0
    if a[0] == "compare":
        return compare(load(a[1]), load(a[2]))
    if a[0] == "selftest":
        mine, google = load(a[1]), load(a[2])
        key = sorted(k for k in mine if "error" not in mine[k])[0]
        bad = json.loads(json.dumps(mine))
        bad[key]["attestationChallenge"] = "ff" + bad[key]["attestationChallenge"]
        if compare(bad, google, quiet=True) == 0:
            print("SELFTEST FAIL: muutettu odotusarvo ei kaatanut vertailua")
            return 1
        print(f"selftest ok: muutettu arvo ({key}) kaatoi vertailun")
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
