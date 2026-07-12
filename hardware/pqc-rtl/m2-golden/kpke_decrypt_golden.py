#!/usr/bin/env python3
"""M3 Issue #8: K-PKE.Decrypt (FIPS 203 Algoritmi 15), k=2 (ML-KEM-512),
du=10, dv=4. Kiintea testiavain ja -salateksti (ei KeyGen/Encrypt, koska
ne vaativat Keccakia - Issue #9, oma tyonsa).

VAIHEISTETTU (kayttajan ehdotuksen mukaisesti):
  Vaihe 1: ciphertextin purku (ByteDecode+Decompress) -> u', v'
  Vaihe 2: NTT-polku (NTT, MultiplyNTTs, summa) - ennen inverse-NTT:ta
  Vaihe 3: puuttuva inverse NTT (oma tyonsa, RTL:ssa viela tekematta)
  Vaihe 4: Compress1(w) + koko ketju end-to-end

TARKEA KORJAUS: Decompress(Compress(x)) ON HAVIOLLINEN operaatio - siksi
NTT-polku (Vaihe 2+) kayttaa PURETTUA arvoa (decompress(compress(u))),
EI alkuperaista nayteta u_prime_raw:ta suoraan. Tama vastaa oikeaa
algoritmia: Decrypt saa vain pakatun ciphertextin, ei alkuperaista
tarkkaa arvoa jonka Encrypt aikanaan laski."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from kyber_ntt_golden import ntt, ntt_inv, multiply_ntts, Q
from compress_golden import compress, decompress
from byteencode_golden import byte_encode, byte_decode

import random
random.seed(2026)

K = 2
DU = 10
DV = 4


def mod_add_poly(a, b):
    return [(x + y) % Q for x, y in zip(a, b)]


def mod_sub_poly(a, b):
    return [(x - y) % Q for x, y in zip(a, b)]


def pack_coeffs(coeffs, width=16):
    val = 0
    for i, c in enumerate(coeffs):
        val |= (c & ((1 << width) - 1)) << (i * width)
    return val


def pack_bytes(byte_list):
    val = 0
    for k, b in enumerate(byte_list):
        val |= (b & 0xFF) << (8 * k)
    return val


def pack_bits(bit_list):
    val = 0
    for i, b in enumerate(bit_list):
        val |= (b & 1) << i
    return val


# --- Kiintea "testiavain": s_hat (jo NTT-domainissa, kuten dkPKE:ssa oikeasti) ---
s_hat = [[random.randrange(Q) for _ in range(256)] for _ in range(K)]

# --- Alkuperaiset (kuvitteellisen Encryptin laskemat, ENNEN pakkausta) u/v ---
u_prime_raw = [[random.randrange(Q) for _ in range(256)] for _ in range(K)]
v_prime_raw = [random.randrange(Q) for _ in range(256)]

# --- Ciphertext: Compress+ByteEncode (K-PKE.Encrypt, rivit 22-23) ---
c1_per_poly = [byte_encode(DU, [compress(DU, x) for x in u_prime_raw[i]]) for i in range(K)]
c2 = byte_encode(DV, [compress(DV, x) for x in v_prime_raw])

# --- VAIHE 1: purku (K-PKE.Decrypt rivit 3-4) - HAVIOLLINEN, tama on
# TODELLINEN u'/v' jota loppuosa kayttaa, EI u_prime_raw/v_prime_raw ---
u_prime = [[decompress(DU, y) for y in byte_decode(DU, c1_per_poly[i])] for i in range(K)]
v_prime = [decompress(DV, y) for y in byte_decode(DV, c2)]

# --- VAIHE 2: NTT-polku ennen inverse-NTT:ta ---
u_hat = [ntt(u_prime[i]) for i in range(K)]
partial = [multiply_ntts(s_hat[i], u_hat[i]) for i in range(K)]
sum_hat = partial[0]
for i in range(1, K):
    sum_hat = mod_add_poly(sum_hat, partial[i])

# --- VAIHE 3+4: inverse NTT + lopullinen paatos (RTL:ssa viela puuttuu
# inverse NTT - ks. Issue #8:n oma keskustelu) ---
inner = ntt_inv(sum_hat)
w = mod_sub_poly(v_prime, inner)
w_compressed = [compress(1, x) for x in w]
m_bytes = byte_encode(1, w_compressed)


if __name__ == "__main__":
    outdir = os.path.join(os.path.dirname(__file__), "..", "vectors")

    # --- Vaihe 1:n omat vektorit: ciphertext-tavut sisaan, u'/v' ulos ---
    with open(os.path.join(outdir, "kpke_stage1_vectors.txt"), "w") as f:
        for i in range(K):
            f.write(f"{pack_bytes(c1_per_poly[i]):x}\n")
        f.write(f"{pack_bytes(c2):x}\n")
        for i in range(K):
            f.write(f"{pack_coeffs(u_prime[i]):x}\n")
        f.write(f"{pack_coeffs(v_prime):x}\n")

    # --- Vaihe 2:n omat vektorit: u'/s_hat sisaan, sum_hat ulos ---
    with open(os.path.join(outdir, "kpke_stage2_vectors.txt"), "w") as f:
        for i in range(K):
            f.write(f"{pack_coeffs(s_hat[i]):x}\n")
        for i in range(K):
            f.write(f"{pack_coeffs(u_prime[i]):x}\n")
        f.write(f"{pack_coeffs(sum_hat):x}\n")

    # --- Koko ketjun lopputulos (myohempaa end-to-end-testia varten) ---
    with open(os.path.join(outdir, "kpke_decrypt_full_vectors.txt"), "w") as f:
        f.write(f"{pack_coeffs(w):x}\n")
        f.write(f"{pack_bits(w_compressed):x}\n")
        f.write(f"{pack_bytes(m_bytes):x}\n")

    print(f"K-PKE.Decrypt golden-arvot generoitu (k={K}, du={DU}, dv={DV})")
    print(f"Vaihe 1 tarkistus: u_prime[0][0:5] = {u_prime[0][:5]}")
    print(f"Vaihe 2 tarkistus: sum_hat[0:5] = {sum_hat[:5]}")
    print(f"m (32 tavua): {bytes(m_bytes).hex()}")
