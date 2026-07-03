#!/usr/bin/env python3
"""Golden-vektorit RVV-Montgomery-reduktiolle. Sama Q/QINV kuin muualla
tassa repossa (wem_bridge, RTL M1) - Kyber-parametrit."""
import random

Q = 3329
QINV = 62209
R = 1 << 16

def mont_reduce(a: int) -> int:
    u = ((a & (R - 1)) * QINV) & (R - 1)
    t = (a + u * Q) >> 16
    if t >= Q:
        t -= Q
    return t

random.seed(42)
vals = [random.randrange(0, Q * Q) for _ in range(8)]
exp = [mont_reduce(v) for v in vals]

with open("vectors.h", "w") as f:
    f.write("#include <stdint.h>\n")
    f.write("static const uint32_t IN_VALS[8] = {" + ",".join(map(str, vals)) + "};\n")
    f.write("static const uint16_t EXPECTED[8] = {" + ",".join(map(str, exp)) + "};\n")

print("vectors.h kirjoitettu")
for v, e in zip(vals, exp):
    print(f"  {v} -> {e}")
