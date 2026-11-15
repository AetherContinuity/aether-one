#!/usr/bin/env python3
"""K=3 (ML-KEM-768) -vektorit TAU-kehyksen Wishbone-testipenkeille.

Poimii yhden tapauksen kustakin fpga/tau/acvp/*_768.txt-tiedostosta
(NIST ACVP, ks. fpga/tau/acvp/README.md) samaan muotoon kuin K=2:n
vanhat tiedostot:
  vectors/mlkem_keygen_vectors_768.txt     d, z, ek, dk   (keyGen tcId=26)
  fpga/tau/encaps_top_e2e_vectors_768.txt  ek, m, K, c    (encaps tcId=26)
  fpga/tau/decaps_top_e2e_vectors_768.txt  dk, c, K       (ensimmainen valid-tapaus)
Ajetaan hardware/pqc-rtl-hakemistosta."""
import sys


def cases(path):
    lines = [l.strip() for l in open(path) if l.strip()]
    n, rest, size = int(lines[0]), lines[1:], (len(lines) - 1) // int(lines[0])
    return [rest[i * size:(i + 1) * size] for i in range(n)]


def write(path, rows):
    open(path, "w").write("\n".join(rows) + "\n")
    print(path)


kg = cases("fpga/tau/acvp/keygen_768.txt")[0]          # tcId, d, z, ek, dk
write("vectors/mlkem_keygen_vectors_768.txt", kg[1:])
en = cases("fpga/tau/acvp/encaps_768.txt")[0]          # tcId, ek, m, K, c
write("fpga/tau/encaps_top_e2e_vectors_768.txt", en[1:])
de = next(c for c in cases("fpga/tau/acvp/decaps_768.txt") if c[0].split()[1] == "0")
write("fpga/tau/decaps_top_e2e_vectors_768.txt", de[1:])  # dk, c, K
print("keygen tcId", kg[0], "encaps tcId", en[0], "decaps tcId", de[0].split()[0], file=sys.stderr)
