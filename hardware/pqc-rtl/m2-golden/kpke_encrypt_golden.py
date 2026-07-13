#!/usr/bin/env python3
"""M3 Issue #15 (jatko): K-PKE.Encrypt, FIPS 203 Algoritmi 14
(LOPULLINEN teksti, haettu ja vahvistettu nvlpubs.nist.gov:sta).

KRIITTISET VAHVISTETUT YKSITYISKOHDAT:
- A_hat[i,j] = SampleNTT(rho||j||i) - TASMALLEEN SAMA kuin K-PKE.KeyGen
  (Issue #15), EI transponoitu generoinnissa.
- Transponointi tapahtuu VASTA KAAVASSA: u = NTT^-1(A_hat^T . y_hat) + e1,
  eli u[i] = sum_j A_hat[j][i] * y_hat[j] (indeksit VAIHDETTU summassa).
- eta2 (ei eta1) kaytetaan e1:n ja e2:n naytteenottoon - eri kuin y,
  joka kayttaa eta1:ta.
- u on KOKO k-pituinen vektori (matriisi-vektori-tulo, k eri NTT^-1-
  kutsua), v on YKSI polynomi (pistetulo, sama rakenne kuin
  K-PKE.Decryptin oma w-laskenta, Issue #8)."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from keccak_golden import sha3_512, shake256
from samplentt_golden import sample_ntt
from samplepolycbd_golden import sample_poly_cbd
from kyber_ntt_golden import ntt, ntt_inv, multiply_ntts, Q
from byteencode_golden import byte_encode, byte_decode
from compress_golden import compress, decompress


def prf(eta, s, b):
    return shake256(s + bytes([b]), 64 * eta)


def mod_add_poly(a, b):
    return [(x + y) % Q for x, y in zip(a, b)]


def kpke_keygen(d_seed, K, ETA1):
    G_out = sha3_512(d_seed + bytes([K]))
    rho, sigma = G_out[:32], G_out[32:]
    A = [[sample_ntt(rho, byte_j=j, byte_i=i) for j in range(K)] for i in range(K)]
    N = 0
    s_vec, e_vec = [], []
    for i in range(K):
        s_vec.append(sample_poly_cbd(prf(ETA1, sigma, N), ETA1))
        N += 1
    for i in range(K):
        e_vec.append(sample_poly_cbd(prf(ETA1, sigma, N), ETA1))
        N += 1
    s_hat = [ntt(s_vec[i]) for i in range(K)]
    e_hat = [ntt(e_vec[i]) for i in range(K)]
    t_hat = []
    for i in range(K):
        acc = [0] * 256
        for j in range(K):
            acc = mod_add_poly(acc, multiply_ntts(A[i][j], s_hat[j]))
        t_hat.append(mod_add_poly(acc, e_hat[i]))
    ekPKE = b"".join(bytes(byte_encode(12, t_hat[i])) for i in range(K)) + rho
    dkPKE = b"".join(bytes(byte_encode(12, s_hat[i])) for i in range(K))
    return ekPKE, dkPKE, A, t_hat, rho


def kpke_encrypt(ekPKE, m_msg, r_seed, K, ETA1, ETA2, DU, DV):
    t_hat = [byte_decode(12, list(ekPKE[i * 384:(i + 1) * 384])) for i in range(K)]
    rho = ekPKE[384 * K:384 * K + 32]

    A = [[sample_ntt(rho, byte_j=j, byte_i=i) for j in range(K)] for i in range(K)]

    N = 0
    y_vec = []
    for i in range(K):
        y_vec.append(sample_poly_cbd(prf(ETA1, r_seed, N), ETA1))
        N += 1
    e1_vec = []
    for i in range(K):
        e1_vec.append(sample_poly_cbd(prf(ETA2, r_seed, N), ETA2))
        N += 1
    e2 = sample_poly_cbd(prf(ETA2, r_seed, N), ETA2)

    y_hat = [ntt(y_vec[i]) for i in range(K)]

    # u[i] = NTT^-1( sum_j A[j][i] * y_hat[j] ) + e1[i]  (A^T - transponoitu summassa)
    u_vec = []
    for i in range(K):
        acc = [0] * 256
        for j in range(K):
            acc = mod_add_poly(acc, multiply_ntts(A[j][i], y_hat[j]))
        u_vec.append(mod_add_poly(ntt_inv(acc), e1_vec[i]))

    m_bits = byte_decode(1, list(m_msg))
    mu = [decompress(1, b) for b in m_bits]

    acc_v = [0] * 256
    for j in range(K):
        acc_v = mod_add_poly(acc_v, multiply_ntts(t_hat[j], y_hat[j]))
    v_poly = mod_add_poly(mod_add_poly(ntt_inv(acc_v), e2), mu)

    c1 = b"".join(bytes(byte_encode(DU, [compress(DU, x) for x in u_vec[i]])) for i in range(K))
    c2 = bytes(byte_encode(DV, [compress(DV, x) for x in v_poly]))

    return c1 + c2, u_vec, v_poly


if __name__ == "__main__":
    K, ETA1, ETA2, DU, DV = 2, 3, 2, 10, 4  # ML-KEM-512

    d_seed = bytes(range(1, 33))
    ekPKE, dkPKE, A_keygen, t_hat_keygen, rho_keygen = kpke_keygen(d_seed, K, ETA1)

    m_msg = bytes(range(32))
    r_seed = bytes(range(64, 96))
    c, u_vec, v_poly = kpke_encrypt(ekPKE, m_msg, r_seed, K, ETA1, ETA2, DU, DV)

    print(f"ekPKE ({len(ekPKE)} tavua), dkPKE ({len(dkPKE)} tavua)")
    print(f"c ({len(c)} tavua, odotettu {32*(DU*K+DV)}): {c.hex()[:32]}...")
    print(f"u_vec[0][0:5]={u_vec[0][:5]}")
    print(f"v_poly[0:5]={v_poly[:5]}")
