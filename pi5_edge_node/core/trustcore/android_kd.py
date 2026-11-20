#!/usr/bin/env python3
"""Android KeyDescription (OID 1.3.6.1.4.1.11129.2.1.17) -jäsennin. Vain vakiokirjasto.

Mitataan Googlen jäsennintä (google/android-key-attestation) vasten
CI:ssä (docs/VAIHE2-ENNAKKO.md K7). Jäsentää tiukan DER:n; ainoa sallittu
poikkeama on deviceLocked-BOOLEANin BER-arvo 0x01 (oikea laite, ks. alla).

KeyDescription ::= SEQUENCE {
  attestationVersion INTEGER, attestationSecurityLevel ENUMERATED,
  keyMintVersion INTEGER, keyMintSecurityLevel ENUMERATED,
  attestationChallenge OCTET STRING, uniqueId OCTET STRING,
  softwareEnforced AuthorizationList, hardwareEnforced AuthorizationList }
AuthorizationList ::= SEQUENCE { [n] EXPLICIT ... OPTIONAL, ... }
"""

from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple

KEY_DESCRIPTION_OID = "1.3.6.1.4.1.11129.2.1.17"

SECURITY_LEVELS = {0: "SOFTWARE", 1: "TRUSTED_ENVIRONMENT", 2: "STRONG_BOX"}
BOOT_STATES = {0: "VERIFIED", 1: "SELF_SIGNED", 2: "UNVERIFIED", 3: "FAILED"}
PURPOSES = {0: "ENCRYPT", 1: "DECRYPT", 2: "SIGN", 3: "VERIFY", 5: "WRAP_KEY",
            6: "AGREE_KEY", 7: "ATTEST_KEY"}
ALGORITHMS = {1: "RSA", 3: "EC"}

TAG_PURPOSE = 1
TAG_ALGORITHM = 2
TAG_ROOT_OF_TRUST = 704
TAG_OS_VERSION = 705
TAG_OS_PATCH_LEVEL = 706
TAG_VENDOR_PATCH_LEVEL = 718
TAG_BOOT_PATCH_LEVEL = 719


class KDError(ValueError):
    pass


# --- DER ------------------------------------------------------------------

def read_tlv(b: bytes, i: int) -> Tuple[int, int, bool, int, int]:
    """Palauttaa (luokka, tagi, rakenteinen, sisällön alku, sisällön loppu)."""
    if i >= len(b):
        raise KDError("DER katkeaa (tagi)")
    t = b[i]
    cls, cons, tag = t >> 6, bool(t & 0x20), t & 0x1F
    i += 1
    if tag == 0x1F:
        tag = 0
        while True:
            if i >= len(b):
                raise KDError("DER katkeaa (pitkä tagi)")
            c = b[i]
            i += 1
            tag = (tag << 7) | (c & 0x7F)
            if not c & 0x80:
                break
        if tag < 31:
            raise KDError("pitkä tagimuoto lyhyelle tagille (ei DER)")
    if i >= len(b):
        raise KDError("DER katkeaa (pituus)")
    ln = b[i]
    i += 1
    if ln & 0x80:
        n = ln & 0x7F
        if n == 0 or n > 4 or i + n > len(b):
            raise KDError("virheellinen pituuskenttä")
        ln = int.from_bytes(b[i:i + n], "big")
        if ln < 0x80 or b[i] == 0:
            raise KDError("pituus ei minimaalinen (ei DER)")
        i += n
    end = i + ln
    if end > len(b):
        raise KDError("DER katkeaa (sisältö)")
    return cls, tag, cons, i, end


def children(b: bytes, start: int, end: int) -> List[Tuple[int, int, bool, int, int]]:
    out = []
    i = start
    while i < end:
        cls, tag, cons, s, e = read_tlv(b, i)
        if e > end:
            raise KDError("lapsi ylittää vanhemman")
        out.append((cls, tag, cons, s, e))
        i = e
    return out


def _int(b: bytes, s: int, e: int) -> int:
    if e == s:
        raise KDError("tyhjä INTEGER")
    return int.from_bytes(b[s:e], "big", signed=True)


def _expect(node, cls: int, tag: int, what: str) -> None:
    if node[0] != cls or node[1] != tag:
        raise KDError(f"{what}: odotettu luokka {cls} tagi {tag}, saatu {node[0]}/{node[1]}")


UNIVERSAL, CONTEXT = 0, 2
T_BOOL, T_INT, T_OCTET, T_ENUM, T_SEQ, T_SET = 1, 2, 4, 10, 16, 17


# --- AuthorizationList -----------------------------------------------------

def _root_of_trust(b: bytes, s: int, e: int) -> Dict[str, Any]:
    kids = children(b, s, e)
    if len(kids) < 3:
        raise KDError("RootOfTrust: liian vähän kenttiä")
    _expect(kids[0], UNIVERSAL, T_OCTET, "verifiedBootKey")
    _expect(kids[1], UNIVERSAL, T_BOOL, "deviceLocked")
    _expect(kids[2], UNIVERSAL, T_ENUM, "verifiedBootState")
    lk = b[kids[1][3]:kids[1][4]]
    if len(lk) != 1:
        raise KDError("deviceLocked ei ole yhden tavun BOOLEAN")
    # Sallittu poikkeama: Pixel 3:n StrongBox (Titan M) koodaa toden arvolla 0x01
    # (BER), DER vaatii 0xFF. Googlen jäsennin hyväksyy; nolla = epätosi.
    st = _int(b, kids[2][3], kids[2][4])
    out: Dict[str, Any] = {
        "verifiedBootKey": b[kids[0][3]:kids[0][4]].hex(),
        "deviceLocked": lk != b"\x00",
        "verifiedBootState": BOOT_STATES.get(st, f"TUNTEMATON({st})"),
        "verifiedBootHash": None,
    }
    if len(kids) >= 4:
        _expect(kids[3], UNIVERSAL, T_OCTET, "verifiedBootHash")
        out["verifiedBootHash"] = b[kids[3][3]:kids[3][4]].hex()
    return out


def parse_authorization_list(b: bytes, s: int, e: int) -> Dict[str, Any]:
    """Palauttaa vertailtavat kentät; muut tagit kirjataan vain numeroina."""
    out: Dict[str, Any] = {"purpose": [], "algorithm": None, "rootOfTrust": None,
                           "osVersion": None, "osPatchLevel": None,
                           "vendorPatchLevel": None, "bootPatchLevel": None, "tags": []}
    seen = set()
    for cls, tag, cons, cs, ce in children(b, s, e):
        if cls != CONTEXT or not cons:
            raise KDError(f"AuthorizationList: odottamaton elementti {cls}/{tag}")
        if tag in seen:
            raise KDError(f"AuthorizationList: tagi {tag} kahdesti")
        seen.add(tag)
        out["tags"].append(tag)
        inner = children(b, cs, ce)
        if len(inner) != 1:
            raise KDError(f"tagi {tag}: EXPLICIT-kääreessä ei tasan yksi arvo")
        v = inner[0]
        if tag == TAG_PURPOSE:
            _expect(v, UNIVERSAL, T_SET, "purpose")
            out["purpose"] = sorted(PURPOSES.get(_int(b, x[3], x[4]), f"TUNTEMATON({_int(b, x[3], x[4])})")
                                    for x in children(b, v[3], v[4]))
        elif tag == TAG_ALGORITHM:
            _expect(v, UNIVERSAL, T_INT, "algorithm")
            a = _int(b, v[3], v[4])
            out["algorithm"] = ALGORITHMS.get(a, f"TUNTEMATON({a})")
        elif tag == TAG_ROOT_OF_TRUST:
            _expect(v, UNIVERSAL, T_SEQ, "rootOfTrust")
            out["rootOfTrust"] = _root_of_trust(b, v[3], v[4])
        elif tag in (TAG_OS_VERSION, TAG_OS_PATCH_LEVEL, TAG_VENDOR_PATCH_LEVEL, TAG_BOOT_PATCH_LEVEL):
            _expect(v, UNIVERSAL, T_INT, f"tagi {tag}")
            key = {TAG_OS_VERSION: "osVersion", TAG_OS_PATCH_LEVEL: "osPatchLevel",
                   TAG_VENDOR_PATCH_LEVEL: "vendorPatchLevel", TAG_BOOT_PATCH_LEVEL: "bootPatchLevel"}[tag]
            out[key] = _int(b, v[3], v[4])
    return out


def parse_key_description(ext_value: bytes) -> Dict[str, Any]:
    """ext_value = laajennuksen extnValue-oktettien sisältö (KeyDescription-SEQUENCE)."""
    cls, tag, cons, s, e = read_tlv(ext_value, 0)
    if (cls, tag) != (UNIVERSAL, T_SEQ) or e != len(ext_value):
        raise KDError("KeyDescription ei ole yksi SEQUENCE")
    k = children(ext_value, s, e)
    if len(k) < 8:
        raise KDError("KeyDescription: alle 8 kenttää")
    for idx, t, nm in ((0, T_INT, "attestationVersion"), (1, T_ENUM, "attestationSecurityLevel"),
                       (2, T_INT, "keyMintVersion"), (3, T_ENUM, "keyMintSecurityLevel"),
                       (4, T_OCTET, "attestationChallenge"), (5, T_OCTET, "uniqueId"),
                       (6, T_SEQ, "softwareEnforced"), (7, T_SEQ, "hardwareEnforced")):
        _expect(k[idx], UNIVERSAL, t, nm)
    sl = _int(ext_value, k[1][3], k[1][4])
    kl = _int(ext_value, k[3][3], k[3][4])
    return {
        "attestationVersion": _int(ext_value, k[0][3], k[0][4]),
        "attestationSecurityLevel": SECURITY_LEVELS.get(sl, f"TUNTEMATON({sl})"),
        "keyMintVersion": _int(ext_value, k[2][3], k[2][4]),
        "keyMintSecurityLevel": SECURITY_LEVELS.get(kl, f"TUNTEMATON({kl})"),
        "attestationChallenge": ext_value[k[4][3]:k[4][4]].hex(),
        "uniqueId": ext_value[k[5][3]:k[5][4]].hex(),
        "softwareEnforced": parse_authorization_list(ext_value, k[6][3], k[6][4]),
        "hardwareEnforced": parse_authorization_list(ext_value, k[7][3], k[7][4]),
    }


def find_extension(cert_der: bytes, oid: str = KEY_DESCRIPTION_OID) -> Optional[bytes]:
    """Laajennuksen arvo X.509-varmenteesta (DER), tai None. Käyttää cryptographya."""
    from cryptography import x509
    c = x509.load_der_x509_certificate(cert_der)
    try:
        ext = c.extensions.get_extension_for_oid(x509.ObjectIdentifier(oid))
    except x509.ExtensionNotFound:
        return None
    return ext.value.value  # UnrecognizedExtension: raakaoktetit
