#!/usr/bin/env python3
"""M3 Issue #9 (#10 esityo): Keccak-p[1600,24] + sponge-rakenne, Python
golden-malli FIPS 202:n omasta tekstista. Tallentaa jokaisen 24 kierroksen
TILAN (ei vain lopputulosta) - mahdollistaa stage-by-stage-vertailun
RTL:aa vastaan, sama periaate joka osoittautui ratkaisevaksi NTT^-1:n
juurisyyn loytamisessa (ks. NTT_INVERSE_DESIGN_NOTE.md).

TARKISTETTU riippumatonta ulkoista referenssia (Pythonin oma hashlib,
joka kayttaa OpenSSL:n Keccak/SHA-3-toteutusta - taysin erillinen
koodikanta tasta tiedostosta) vasten - ei luoteta omaan toteutukseen
ilman ulkoista ankkuria."""

import struct


# --- Rho-siirtomaarat (FIPS 202 Taulukko 2, x,y=0..4) ---
# Rho_offsets[x][y] = kierron pituus bitteina lanelle (x,y).
RHO_OFFSETS = [
    [0, 36, 3, 41, 18],
    [1, 44, 10, 45, 2],
    [62, 6, 43, 15, 61],
    [28, 55, 25, 21, 56],
    [27, 20, 39, 8, 14],
]


def _round_constants():
    """FIPS 202 Algoritmi 5 (rc-funktio, LFSR mod x^8+x^6+x^5+x^4+1),
    kaytettyna 24 kierroksen RC(i)-vakioiden generointiin (Algoritmi 6)."""
    def rc(t):
        if t % 255 == 0:
            return 1
        R = 1
        for _ in range(t % 255):
            R = R << 1
            if R & 0x100:
                R ^= 0x171
            R &= 0xFF
        return R & 1

    constants = []
    for round_idx in range(24):
        rc_word = 0
        for j in range(7):
            bit_pos = (1 << j) - 1
            rc_word |= rc(j + 7 * round_idx) << bit_pos
        constants.append(rc_word)
    return constants


RC = _round_constants()


def _rotl64(x, n):
    n %= 64
    return ((x << n) | (x >> (64 - n))) & 0xFFFFFFFFFFFFFFFF


def keccak_f1600(state_lanes, capture_rounds=False):
    """state_lanes: 5x5 lista, state_lanes[x][y] = 64-bittinen kokonaisluku.
    Palauttaa (lopputila, [valitilat_per_kierros] jos capture_rounds)."""
    A = [row[:] for row in state_lanes]
    snapshots = []

    for round_idx in range(24):
        # --- theta ---
        C = [A[x][0] ^ A[x][1] ^ A[x][2] ^ A[x][3] ^ A[x][4] for x in range(5)]
        D = [C[(x - 1) % 5] ^ _rotl64(C[(x + 1) % 5], 1) for x in range(5)]
        for x in range(5):
            for y in range(5):
                A[x][y] ^= D[x]

        # --- rho + pi (yhdistetty: uusi sijainti (y, 2x+3y mod 5), rotaatio RHO_OFFSETS[x][y]) ---
        B = [[0] * 5 for _ in range(5)]
        for x in range(5):
            for y in range(5):
                B[y][(2 * x + 3 * y) % 5] = _rotl64(A[x][y], RHO_OFFSETS[x][y])

        # --- chi ---
        for x in range(5):
            for y in range(5):
                A[x][y] = B[x][y] ^ ((~B[(x + 1) % 5][y]) & B[(x + 2) % 5][y] & 0xFFFFFFFFFFFFFFFF)

        # --- iota ---
        A[0][0] ^= RC[round_idx]

        if capture_rounds:
            snapshots.append([row[:] for row in A])

    return A, snapshots


def bytes_to_state(b):
    """168 tavua (max rate) -> 5x5x64-bittinen tila (loput nollataan)."""
    lanes_flat = [0] * 25
    for i in range(min(len(b) // 8, 25)):
        lanes_flat[i] = struct.unpack_from("<Q", b, i * 8)[0]
    state = [[0] * 5 for _ in range(5)]
    for i in range(25):
        x, y = i % 5, i // 5
        state[x][y] = lanes_flat[i]
    return state


def state_to_bytes(state, n):
    """Poimii ensimmaiset n tavua tilasta (little-endian lane-jarjestys)."""
    lanes_flat = [0] * 25
    for i in range(25):
        x, y = i % 5, i // 5
        lanes_flat[i] = state[x][y]
    out = b"".join(struct.pack("<Q", lanes_flat[i]) for i in range(25))
    return out[:n]


def pad_message(message: bytes, rate_bytes: int, domain_suffix: int) -> bytes:
    """Pad10*1 + domain-suffiksi, tavutasolla (FIPS 202:n oma tavutason
    konventio). Palauttaa TAYDEN, rate_bytes:n monikertaisen pehmennetyn
    viestin. Itsenainen funktio - testataan ERIKSEEN ennen absorbointia
    (kayttajan oma ehdotus, Issue #11 Vaihe A)."""
    msg = bytearray(message)
    msg.append(domain_suffix)
    while len(msg) % rate_bytes != 0:
        msg.append(0x00)
    msg[-1] ^= 0x80
    return bytes(msg)


def keccak_sponge(message: bytes, rate_bytes: int, capacity_bits: int,
                   out_bytes: int, domain_suffix: int) -> bytes:
    """KECCAK[c](N,d), N = message || domain_suffix-bitit || pad10*1.
    domain_suffix: 0x06 (SHA3) tai 0x1F (SHAKE), tavutason konventio."""
    assert capacity_bits % 8 == 0
    state = [[0] * 5 for _ in range(5)]

    msg = pad_message(message, rate_bytes, domain_suffix)

    # --- Absorbointi ---
    for i in range(0, len(msg), rate_bytes):
        block = bytes(msg[i:i + rate_bytes])
        block_lanes = bytes_to_state(block + b"\x00" * (168 - len(block)))
        for x in range(5):
            for y in range(5):
                state[x][y] ^= block_lanes[x][y]
        state, _ = keccak_f1600(state)

    # --- Puristus ---
    out = b""
    while len(out) < out_bytes:
        out += state_to_bytes(state, rate_bytes)
        if len(out) < out_bytes:
            state, _ = keccak_f1600(state)
    return out[:out_bytes]


def sha3_256(message: bytes) -> bytes:
    return keccak_sponge(message, rate_bytes=136, capacity_bits=512, out_bytes=32, domain_suffix=0x06)


def sha3_512(message: bytes) -> bytes:
    return keccak_sponge(message, rate_bytes=72, capacity_bits=1024, out_bytes=64, domain_suffix=0x06)


def shake128(message: bytes, out_bytes: int) -> bytes:
    return keccak_sponge(message, rate_bytes=168, capacity_bits=256, out_bytes=out_bytes, domain_suffix=0x1F)


def shake256(message: bytes, out_bytes: int) -> bytes:
    return keccak_sponge(message, rate_bytes=136, capacity_bits=512, out_bytes=out_bytes, domain_suffix=0x1F)


if __name__ == "__main__":
    import hashlib

    print("=== Tarkistus riippumatonta hashlib-referenssia vasten ===")
    test_messages = [
        b"",
        b"abc",
        b"a" * 135,   # 1 tavu alle SHA3-256:n rate:n (136)
        b"a" * 136,   # TASAN SHA3-256:n rate - reunatapaus (domain+0x80 eri lohkoihin)
        b"a" * 137,   # 1 tavu yli
        b"a" * 1000,  # useita lohkoja
    ]

    all_ok = True
    for msg in test_messages:
        ours = sha3_256(msg).hex()
        theirs = hashlib.sha3_256(msg).hexdigest()
        ok = ours == theirs
        all_ok &= ok
        print(f"SHA3-256 len={len(msg):5d}: {'OK' if ok else 'FAIL'} ({ours[:16]}... vs {theirs[:16]}...)")

    for msg in test_messages:
        ours = sha3_512(msg).hex()
        theirs = hashlib.sha3_512(msg).hexdigest()
        ok = ours == theirs
        all_ok &= ok
        print(f"SHA3-512 len={len(msg):5d}: {'OK' if ok else 'FAIL'}")

    for msg in test_messages:
        for outlen in [16, 32, 64, 168, 200]:
            ours = shake128(msg, outlen).hex()
            theirs = hashlib.shake_128(msg).hexdigest(outlen)
            ok = ours == theirs
            all_ok &= ok
            if not ok:
                print(f"SHAKE128 len={len(msg):5d} out={outlen}: FAIL")

    for msg in test_messages:
        for outlen in [16, 32, 64, 136, 200]:
            ours = shake256(msg, outlen).hex()
            theirs = hashlib.shake_256(msg).hexdigest(outlen)
            ok = ours == theirs
            all_ok &= ok
            if not ok:
                print(f"SHAKE256 len={len(msg):5d} out={outlen}: FAIL")

    print()
    print("KAIKKI TESTIT OK" if all_ok else "JOITAKIN VIRHEITA - EI KAYTETA GOLDEN-MALLINA VIELA")
