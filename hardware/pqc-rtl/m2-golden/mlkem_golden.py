#!/usr/bin/env python3
"""M3 Issue #15 (viimeinen osa): ML-KEM:n ulompi kuori (Algoritmit
16-21), FIPS 203:n LOPULLISESTA tekstista (nvlpubs.nist.gov), haettu
ja vahvistettu tata kirjoitettaessa.

KRIITTISET VAHVISTETUT YKSITYISKOHDAT:
- KeyGen_internal: dk = dkPKE||ek||H(ek)||z (KIINTEA 4-osainen
  rakenne, ei mitaan muuta jarjestysta).
- Encaps_internal: K on SUORAAN G(m||H(ek)):n ensimmainen puolisko -
  EI erillista lisahajautusta (poikkeaa CRYSTALS-Kyberin alkuperaisesta
  FO-muunnoksesta, dokumentoitu FIPS 203 Liite C.1:ssa).
- Decaps_internal: Fujisaki-Okamoto-muunnos implisiittisella
  hylkayksella - jos uudelleensalattu c' != c, palautetun avaimen
  tilalle vaihdetaan K_bar = J(z||c), EI alkuperaista K':ta.

Kayttaa jo validoituja K-PKE-golden-malleja (kpke_encrypt_golden.py)
suoraan - EI uutta kryptografista logiikkaa, vain orkestrointi."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from keccak_golden import sha3_256, sha3_512, shake256
from kpke_encrypt_golden import kpke_keygen, kpke_encrypt
from kyber_ntt_golden import ntt, ntt_inv, multiply_ntts, Q
from byteencode_golden import byte_encode, byte_decode
from compress_golden import compress, decompress


def kpke_decrypt(dkPKE, c, K_dim, DU=10, DV=4):
    """FIPS 203 Algoritmi 15."""
    c1 = c[:32 * DU * K_dim]
    c2 = c[32 * DU * K_dim:]
    u_prime = [[decompress(DU, y) for y in byte_decode(DU, list(c1[i*32*DU:(i+1)*32*DU]))] for i in range(K_dim)]
    v_prime = [decompress(DV, y) for y in byte_decode(DV, list(c2))]
    s_hat = [byte_decode(12, list(dkPKE[i*384:(i+1)*384])) for i in range(K_dim)]
    u_hat = [ntt(u_prime[i]) for i in range(K_dim)]

    def mod_add_poly(a, b): return [(x + y) % Q for x, y in zip(a, b)]
    def mod_sub_poly(a, b): return [(x - y) % Q for x, y in zip(a, b)]

    acc = [0] * 256
    for i in range(K_dim):
        acc = mod_add_poly(acc, multiply_ntts(s_hat[i], u_hat[i]))
    inner = ntt_inv(acc)
    w = mod_sub_poly(v_prime, inner)
    return bytes(byte_encode(1, [compress(1, x) for x in w]))


def mlkem_keygen_internal(d, z, K_dim, ETA1):
    """FIPS 203 Algoritmi 16."""
    ekPKE, dkPKE, A, t_hat, rho = kpke_keygen(d, K_dim, ETA1)
    ek = ekPKE
    dk = dkPKE + ek + sha3_256(ek) + z
    return ek, dk


def mlkem_encaps_internal(ek, m, K_dim, ETA1, ETA2, DU, DV):
    """FIPS 203 Algoritmi 17."""
    G_out = sha3_512(m + sha3_256(ek))
    K, r = G_out[:32], G_out[32:]
    c, _, _ = kpke_encrypt(ek, m, r, K_dim, ETA1, ETA2, DU, DV)
    return K, c


def mlkem_decaps_internal(dk, c, K_dim, ETA1, ETA2, DU, DV):
    """FIPS 203 Algoritmi 18 - Fujisaki-Okamoto-muunnos implisiittisella
    hylkayksella."""
    dkPKE = dk[0:384 * K_dim]
    ekPKE = dk[384 * K_dim:768 * K_dim + 32]
    h = dk[768 * K_dim + 32:768 * K_dim + 64]
    z = dk[768 * K_dim + 64:768 * K_dim + 96]

    m_prime = kpke_decrypt(dkPKE, c, K_dim, DU, DV)
    G_out = sha3_512(m_prime + h)
    K_prime, r_prime = G_out[:32], G_out[32:]
    K_bar = shake256(z + c, 32)
    c_prime, _, _ = kpke_encrypt(ekPKE, m_prime, r_prime, K_dim, ETA1, ETA2, DU, DV)

    if c != c_prime:
        K_prime = K_bar
    return K_prime


if __name__ == "__main__":
    K_dim, ETA1, ETA2, DU, DV = 2, 3, 2, 10, 4  # ML-KEM-512

    print("=== Normaali polku: KeyGen -> Encaps -> Decaps, K_bob==K_alice? ===")
    d = bytes(range(1, 33))
    z = bytes(range(33, 65))
    ek, dk = mlkem_keygen_internal(d, z, K_dim, ETA1)
    assert len(ek) == 800 and len(dk) == 1632

    m = bytes(range(65, 97))
    K_bob, c = mlkem_encaps_internal(ek, m, K_dim, ETA1, ETA2, DU, DV)
    assert len(c) == 768

    K_alice = mlkem_decaps_internal(dk, c, K_dim, ETA1, ETA2, DU, DV)
    assert K_bob == K_alice, "VIRHE: K_bob != K_alice normaalilla polulla!"
    print(f"OK: K_bob == K_alice = {K_bob.hex()}")

    print()
    print("=== Implisiittinen hylkays: vaarennetty c ===")
    c_corrupted = bytearray(c)
    c_corrupted[100] ^= 0xFF
    c_corrupted = bytes(c_corrupted)

    K_alice_rejected = mlkem_decaps_internal(dk, c_corrupted, K_dim, ETA1, ETA2, DU, DV)
    z_from_dk = dk[768 * K_dim + 64:768 * K_dim + 96]
    K_bar_expect = shake256(z_from_dk + c_corrupted, 32)

    assert K_alice_rejected != K_bob, "VIRHE: implisiittinen hylkays ei toiminut - K tasmaa alkuperaiseen!"
    assert K_alice_rejected == K_bar_expect, "VIRHE: implisiittinen hylkays ei anna J(z||c)-arvoa!"
    print(f"OK: vaarennetulla c:lla K_alice = J(z||c) = {K_alice_rejected.hex()}")
    print(f"    (!= alkuperainen K_bob = {K_bob.hex()})")

    print()
    print("=== Yhden BITIN muutos (kayttajan oma ehdotus) ===")
    c_bitflip = bytearray(c)
    c_bitflip[50] ^= 0x01  # tasan yksi bitti, ei koko tavu
    c_bitflip = bytes(c_bitflip)

    K_alice_bitflip = mlkem_decaps_internal(dk, c_bitflip, K_dim, ETA1, ETA2, DU, DV)
    z_from_dk2 = dk[768 * K_dim + 64:768 * K_dim + 96]
    K_bar_bitflip_expect = shake256(z_from_dk2 + c_bitflip, 32)

    assert K_alice_bitflip != K_bob, "VIRHE: yhden bitin muutos ei laukaissut hylkaysta!"
    assert K_alice_bitflip == K_bar_bitflip_expect, "VIRHE: hylkays ei anna J(z||c_bitflip):ta!"
    print(f"OK: yhden bitin muutos (tavu 50, bitti 0) laukaisee implisiittisen hylkayksen oikein")
    print(f"    K_alice (bitflip) = {K_alice_bitflip.hex()}")
    print(f"    (!= alkuperainen K_bob = {K_bob.hex()})")
    print(f"    Sama ohjauspolku kuin tavun-hylkays-testi (Decaps_internal rivit 9-11 suoritetaan),")
    print(f"    vain ERI lopputulos (K_bar riippuu c:sta) - todistaa etta vertailu on herkka")
    print(f"    yhdellekin bitille, ei vain koko tavun muutokselle.")

    print()
    print("KAIKKI TARKISTUKSET OK - normaali polku, tavun hylkays, JA yhden bitin hylkays toimivat oikein")
