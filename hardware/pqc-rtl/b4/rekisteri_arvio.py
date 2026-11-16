#!/usr/bin/env python3
"""B4: deklaraatioihin perustuva rekisteribittiarvio ytimen OMALLE tasolle
(ei alimoduuleja). Laskee always_ff-lohkoissa sijoitettujen signaalien
deklaroidut bitit, kun K ja COEFF_W annetaan.

Kaytto: b4/rekisteri_arvio.py <tiedosto.sv> [K] [COEFF_W]

Menetelma (ennakkoon kiinnitetty, B4-ENNAKKO.md):
1. Signaali lasketaan rekisteriksi, jos sita sijoitetaan '<='-operaattorilla.
2. Leveys ja taulukkomitat luetaan 'logic [..] nimi [..][..]' -deklaraatiosta;
   lausekkeet evaluoidaan modulin parametreilla (K, COEFF_W ja johdetut).
3. Porttirekisterit (output logic, joihin sijoitetaan '<=') lasketaan mukaan.
Arvio ei tieda optimoinneista (vakiot, kayttamattomat bitit)."""
import re
import sys


def conv(expr):
    """SV-lauseke -> Python: (ehto) ? a : b -> (a if (ehto) else b), sisimmasta alkaen."""
    pat = re.compile(r"\(([^()?:]*)\)\s*\?\s*([\w]+)\s*:\s*([\w]+)")
    prev = None
    while prev != expr:
        prev = expr
        expr = pat.sub(lambda m: f"({m.group(2)} if ({m.group(1)}) else {m.group(3)})", expr, count=1)
    return expr


def params(src, K, CW):
    env = {"K": K, "COEFF_W": CW}
    for line in src.splitlines():
        m = re.search(r"(?:local)?param(?:eter)?\s+int\s+(\w+)\s*=\s*(.+)", line)
        if not m or m.group(1) in ("K", "COEFF_W"):
            continue
        expr = re.sub(r"\s*(,|;|\)\s*\()?\s*$", "", m.group(2).strip())
        try:
            env[m.group(1)] = int(eval(conv(expr), {}, dict(env)))
        except Exception as e:
            print(f"  (parametri {m.group(1)} = {expr!r} ei evaluoitu: {e})", file=sys.stderr)
    return env


def width(rng, env):
    hi, lo = rng.split(":")
    return abs(int(eval(hi, {}, env)) - int(eval(lo, {}, env))) + 1


def main(path, K=3, CW=16):
    src = open(path).read()
    src_nc = re.sub(r"//.*", "", src)
    env = params(src_nc, K, CW)
    assigned = set(re.findall(r"\b(\w+)\s*(?:\[[^\]]*\])*\s*(?:\[[^\]]*\+:[^\]]*\])?\s*<=", src_nc))
    total, rows = 0, []
    decl = re.compile(r"(?:output\s+)?logic\s*(\[[^\]]+\])?\s*([\w\s,\[\]:\-\+\*/()]+?);")
    for m in re.finditer(r"(?:output\s+)?logic\s*(\[[^\]]+\])?\s+([^;]+);", src_nc):
        w = width(m.group(1)[1:-1], env) if m.group(1) else 1
        for part in m.group(2).split(","):
            pm = re.match(r"\s*(\w+)\s*((?:\[[^\]]+\])*)", part)
            if not pm or pm.group(1) not in assigned:
                continue
            n = 1
            for d in re.findall(r"\[([^\]]+)\]", pm.group(2)):
                n *= width(d, env)
            bits = w * n
            total += bits
            rows.append((bits, pm.group(1)))
    for bits, name in sorted(rows, reverse=True)[:12]:
        print(f"  {bits:8d}  {name}")
    print(f"{path}: K={K} rekisteribitteja (oma taso) {total}")
    return total


if __name__ == "__main__":
    a = sys.argv[1:]
    main(a[0], *(int(x) for x in a[1:]))
