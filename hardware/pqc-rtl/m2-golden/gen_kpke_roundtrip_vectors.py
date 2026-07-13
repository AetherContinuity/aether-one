#!/usr/bin/env python3
"""M3 Issue #15: taydellinen KeyGen->Encrypt->Decrypt-round-trip,
kayttajan oma ehdotus. GENUIINISTI ERI m ja r kuin aiemmissa
erillisissa testeissa (0xAA/0x55-toistot, ei 0..31/64..95-sekvenssit)
- todistaa etta ketju toimii mielivaltaiselle syotteelle, ei vain
sille yhdelle testitapaukselle jota kaikki aiemmat vaiheet kayttivat."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from kpke_encrypt_golden import kpke_keygen, kpke_encrypt
from kyber_ntt_golden import ntt, ntt_inv, multiply_ntts, Q
from byteencode_golden import byte_encode, byte_decode
from compress_golden import compress, decompress

K, ETA1, ETA2, DU, DV = 2, 3, 2, 10, 4
outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")


def mod_add_poly(a, b):
    return [(x + y) % Q for x, y in zip(a, b)]


def mod_sub_poly(a, b):
    return [(x - y) % Q for x, y in zip(a, b)]


def pack_bytes(b):
    val = 0
    for i, byte in enumerate(b):
        val |= byte << (i * 8)
    return val


d_seed = bytes(range(1, 33))
ekPKE, dkPKE, A, t_hat, rho = kpke_keygen(d_seed, K, ETA1)

m_original = bytes([0xAA] * 32)
r_seed = bytes([0x55] * 32)
c, u_vec, v_poly = kpke_encrypt(ekPKE, m_original, r_seed, K, ETA1, ETA2, DU, DV)

c1 = c[:32 * DU * K]
c2 = c[32 * DU * K:]
u_prime = [[decompress(DU, y) for y in byte_decode(DU, list(c1[i * 32 * DU:(i + 1) * 32 * DU]))] for i in range(K)]
v_prime = [decompress(DV, y) for y in byte_decode(DV, list(c2))]
s_hat = [byte_decode(12, list(dkPKE[i * 384:(i + 1) * 384])) for i in range(K)]

u_hat = [ntt(u_prime[i]) for i in range(K)]
acc = [0] * 256
for i in range(K):
    acc = mod_add_poly(acc, multiply_ntts(s_hat[i], u_hat[i]))
inner = ntt_inv(acc)
w = mod_sub_poly(v_prime, inner)
w_compressed = [compress(1, x) for x in w]
m_decrypted = bytes(byte_encode(1, w_compressed))

assert m_decrypted == m_original, "GOLDEN-MALLIN OMA round-trip epaonnistui!"

with open(os.path.join(outdir, "kpke_roundtrip_vectors.txt"), "w") as f:
    f.write(f"d\n{int.from_bytes(d_seed, 'little'):064x}\n")
    f.write(f"m_original\n{pack_bytes(m_original):x}\n")
    f.write(f"r\n{int.from_bytes(r_seed, 'little'):064x}\n")
    f.write(f"ekPKE\n{pack_bytes(ekPKE):x}\n")
    f.write(f"dkPKE\n{pack_bytes(dkPKE):x}\n")
    f.write(f"c\n{pack_bytes(c):x}\n")
    f.write(f"m_decrypted\n{pack_bytes(m_decrypted):x}\n")

print("Taydellinen round-trip vahvistettu golden-mallissa:")
print(f"  m_original  = {m_original.hex()}")
print(f"  m_decrypted = {m_decrypted.hex()}")
print(f"  Decrypt(Encrypt(m)) == m: {m_decrypted == m_original}")
