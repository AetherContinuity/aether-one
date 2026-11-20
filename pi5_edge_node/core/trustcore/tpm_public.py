#!/usr/bin/env python3
"""TPM2B_PUBLIC-jäsennys (RSA) ja PEM-muodostus. Vain vakiokirjasto.

Rekisteröinti (admin.py) lukee AK:n attribuutit binäärirakenteesta eikä
tekstitulosteesta, ja muodostaa todentajan käyttämän PEM:n samasta
rakenteesta. Attribuutit ja avain eivät voi siksi olla ristiriidassa.

Rakenne (TPM 2.0 Part 2, 12.2.4): size(2) | type(2) | nameAlg(2) |
objectAttributes(4) | authPolicy(TPM2B) | parameters | unique(TPM2B).
"""

from __future__ import annotations

import base64
from typing import Dict, List

TPM_ALG_RSA = 0x0001
TPM_ALG_NULL = 0x0010

ATTR_BITS = {
    "fixedtpm": 1 << 1,
    "stclear": 1 << 2,
    "fixedparent": 1 << 4,
    "sensitivedataorigin": 1 << 5,
    "userwithauth": 1 << 6,
    "adminwithpolicy": 1 << 7,
    "noda": 1 << 10,
    "encryptedduplication": 1 << 11,
    "restricted": 1 << 16,
    "decrypt": 1 << 17,
    "sign": 1 << 18,
}

# K2: AK:n on oltava rajoitettu allekirjoitusavain, joka ei poistu TPM:stä.
REQUIRED_AK_ATTRS = ("fixedtpm", "restricted", "sign")
FORBIDDEN_AK_ATTRS = ("decrypt",)


class TPMPublicError(ValueError):
    pass


class _R:
    def __init__(self, b: bytes):
        self.b, self.i = b, 0

    def take(self, n: int) -> bytes:
        if self.i + n > len(self.b):
            raise TPMPublicError("TPM2B_PUBLIC katkeaa kesken")
        v = self.b[self.i:self.i + n]
        self.i += n
        return v

    def u16(self) -> int:
        return int.from_bytes(self.take(2), "big")

    def u32(self) -> int:
        return int.from_bytes(self.take(4), "big")

    def tpm2b(self) -> bytes:
        return self.take(self.u16())


def parse_rsa_public(blob: bytes) -> Dict[str, object]:
    """Jäsentää TSS-muotoisen TPM2B_PUBLIC:n (tpm2_readpublic -f tss -o)."""
    r = _R(blob)
    size = r.u16()
    if size != len(blob) - 2:
        raise TPMPublicError(f"koko {size} ei vastaa dataa {len(blob) - 2}")
    alg = r.u16()
    if alg != TPM_ALG_RSA:
        raise TPMPublicError(f"vain RSA tuettu vaiheessa 1 (type=0x{alg:04x})")
    r.u16()  # nameAlg
    attrs = r.u32()
    r.tpm2b()  # authPolicy
    sym = r.u16()
    if sym != TPM_ALG_NULL:
        r.take(4)  # keyBits + mode
    scheme = r.u16()
    scheme_hash = r.u16() if scheme != TPM_ALG_NULL else None
    key_bits = r.u16()
    exponent = r.u32() or 65537
    modulus = r.tpm2b()
    if r.i != len(blob):
        raise TPMPublicError("ylimääräistä dataa rakenteen lopussa")
    if len(modulus) * 8 != key_bits:
        raise TPMPublicError("modulus ei vastaa keyBits-kenttää")
    names = [k for k, bit in ATTR_BITS.items() if attrs & bit]
    return {"attributes": attrs, "attribute_names": names, "scheme": scheme,
            "scheme_hash": scheme_hash, "key_bits": key_bits,
            "exponent": exponent, "modulus": modulus}


def ak_policy_violations(info: Dict[str, object]) -> List[str]:
    a = int(info["attributes"])  # type: ignore[arg-type]
    out = [f"{n} puuttuu" for n in REQUIRED_AK_ATTRS if not a & ATTR_BITS[n]]
    out += [f"{n} asetettu" for n in FORBIDDEN_AK_ATTRS if a & ATTR_BITS[n]]
    return out


def _der_len(n: int) -> bytes:
    if n < 0x80:
        return bytes([n])
    b = n.to_bytes((n.bit_length() + 7) // 8, "big")
    return bytes([0x80 | len(b)]) + b


def _der(tag: int, body: bytes) -> bytes:
    return bytes([tag]) + _der_len(len(body)) + body


def _der_int(v: int) -> bytes:
    b = v.to_bytes((v.bit_length() + 7) // 8 or 1, "big")
    if b[0] & 0x80:
        b = b"\x00" + b
    return _der(0x02, b)


def rsa_pem(modulus: bytes, exponent: int) -> str:
    """SubjectPublicKeyInfo (rsaEncryption) PEM-muodossa."""
    rsa_oid = bytes.fromhex("06092a864886f70d010101")
    alg = _der(0x30, rsa_oid + b"\x05\x00")
    key = _der(0x30, _der_int(int.from_bytes(modulus, "big")) + _der_int(exponent))
    spki = _der(0x30, alg + _der(0x03, b"\x00" + key))
    b64 = base64.b64encode(spki).decode()
    lines = [b64[i:i + 64] for i in range(0, len(b64), 64)]
    return "-----BEGIN PUBLIC KEY-----\n" + "\n".join(lines) + "\n-----END PUBLIC KEY-----\n"
