#!/usr/bin/env python3
"""Android-attestaatioketjun tarkistus (docs/VAIHE2-ENNAKKO.md K1, K3).

Oma minimaalinen X.509-jäsennin (DER-lukija android_kd.py:stä); cryptography
vain allekirjoitusprimitiivinä. Syy: cryptographyn tiukka jäsennin hylkää
oikeita StrongBox-varmenteita, joiden ecdsa-with-SHA256-algoritmilla on
NULL-parametri (RFC 5758 vaatii puuttuvan). Tämä yksi poikkeama sallitaan ja
kirjataan; muu poikkeava DER on virhe.

Ketju tarkistetaan pareittain kuten Googlen esimerkki: allekirjoitus
ylemmän avaimella (nimien ero kirjataan huomioksi, ei hylätä), voimassaolo
annettuna hetkenä, juuri kiinnitetyssä joukossa. Ei PKIX-polkua: KeyMintin
attest key -varmenteet eivät ole CA-varmenteita.
"""

from __future__ import annotations

import base64
import hashlib
import json
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Dict, List, Optional, Set

from .android_kd import (CONTEXT, T_INT, T_OCTET, T_SEQ, UNIVERSAL, KDError, children,
                         read_tlv)

ROOTS_FILE = Path(__file__).with_name("android_roots.json")
STATUS_MAX_AGE = timedelta(hours=24)

T_BITSTR, T_NULL, T_OID, T_UTC, T_GEN = 3, 5, 6, 23, 24

SIG_ALGS = {
    "1.2.840.113549.1.1.11": ("rsa", "sha256"),
    "1.2.840.113549.1.1.12": ("rsa", "sha384"),
    "1.2.840.113549.1.1.13": ("rsa", "sha512"),
    "1.2.840.10045.4.3.2": ("ec", "sha256"),
    "1.2.840.10045.4.3.3": ("ec", "sha384"),
    "1.2.840.10045.4.3.4": ("ec", "sha512"),
}


class ChainParseError(ValueError):
    pass


def oid_str(b: bytes) -> str:
    if not b:
        raise ChainParseError("tyhjä OID")
    first = b[0]
    parts = [min(first // 40, 2), first - 40 * min(first // 40, 2)]
    v = 0
    for c in b[1:]:
        v = (v << 7) | (c & 0x7F)
        if not c & 0x80:
            parts.append(v)
            v = 0
    return ".".join(map(str, parts))


def _time(b: bytes, node) -> datetime:
    s = b[node[3]:node[4]].decode("ascii")
    if node[1] == T_UTC and len(s) == 13 and s.endswith("Z"):
        y = int(s[:2])
        s = ("19" if y >= 50 else "20") + s
    elif not (node[1] == T_GEN and len(s) == 15 and s.endswith("Z")):
        raise ChainParseError(f"aikamuoto {node[1]} {s!r}")
    return datetime.strptime(s, "%Y%m%d%H%M%SZ").replace(tzinfo=timezone.utc)


@dataclass
class Cert:
    der: bytes
    tbs: bytes
    sig_alg: str
    sig_params_null: bool
    signature: bytes
    serial: int
    issuer: bytes
    subject: bytes
    not_before: datetime
    not_after: datetime
    spki: bytes
    extensions: Dict[str, bytes] = field(default_factory=dict)

    @property
    def sha256(self) -> str:
        return hashlib.sha256(self.der).hexdigest()

    @property
    def spki_sha256(self) -> str:
        return hashlib.sha256(self.spki).hexdigest()


def parse_cert(der: bytes) -> Cert:
    try:
        cls, tag, _, s, e = read_tlv(der, 0)
        if (cls, tag) != (UNIVERSAL, T_SEQ) or e != len(der):
            raise ChainParseError("varmenne ei ole yksi SEQUENCE")
        top = children(der, s, e)
        if len(top) != 3:
            raise ChainParseError("Certificate: ei 3 kenttää")
        tbs_n, alg_n, sig_n = top
        tbs_bytes = der[s:tbs_n[4]]  # tbs on ensimmäinen lapsi: TLV alkaa sisällön alusta
        alg = children(der, alg_n[3], alg_n[4])
        if alg[0][1] != T_OID:
            raise ChainParseError("signatureAlgorithm ilman OID:ia")
        sig_alg = oid_str(der[alg[0][3]:alg[0][4]])
        null = False
        if len(alg) == 2 and alg[1][1] == T_NULL and alg[1][4] == alg[1][3]:
            null = True
        elif len(alg) != 1 and not sig_alg.startswith("1.2.840.113549"):
            raise ChainParseError("signatureAlgorithm: odottamattomat parametrit")
        if sig_n[1] != T_BITSTR or der[sig_n[3]] != 0:
            raise ChainParseError("signatureValue ei ole BIT STRING (0 täytebittiä)")
        signature = der[sig_n[3] + 1:sig_n[4]]

        t = children(der, tbs_n[3], tbs_n[4])
        i = 0
        if t[0][0] == CONTEXT and t[0][1] == 0:
            i = 1
        serial_n, _sigalg2, iss_n, val_n, sub_n, spki_n = t[i:i + 6]
        if serial_n[1] != T_INT:
            raise ChainParseError("serialNumber")
        serial = int.from_bytes(der[serial_n[3]:serial_n[4]], "big", signed=True)
        val = children(der, val_n[3], val_n[4])
        exts: Dict[str, bytes] = {}
        for node in t[i + 6:]:
            if node[0] == CONTEXT and node[1] == 3:
                (seq,) = children(der, node[3], node[4])
                for ext in children(der, seq[3], seq[4]):
                    parts = children(der, ext[3], ext[4])
                    oid = oid_str(der[parts[0][3]:parts[0][4]])
                    val_node = parts[-1]
                    if val_node[1] != T_OCTET:
                        raise ChainParseError("extnValue ei ole OCTET STRING")
                    if oid in exts:
                        raise ChainParseError(f"laajennus {oid} kahdesti")
                    exts[oid] = der[val_node[3]:val_node[4]]
        return Cert(
            der=der, tbs=tbs_bytes, sig_alg=sig_alg, sig_params_null=null, signature=signature,
            serial=serial, issuer=der[_node_start(t, iss_n):iss_n[4]],
            subject=der[_node_start(t, sub_n):sub_n[4]],
            not_before=_time(der, val[0]), not_after=_time(der, val[1]),
            spki=der[_node_start(t, spki_n):spki_n[4]], extensions=exts)
    except (KDError, ValueError, IndexError) as ex:
        if isinstance(ex, ChainParseError):
            raise
        raise ChainParseError(str(ex))


def _node_start(siblings, node) -> int:
    """Lapsen TLV:n alku: edellisen sisaruksen loppu (tai vanhemman sisällön alku)."""
    idx = siblings.index(node)
    if idx == 0:
        raise ChainParseError("sisäinen: ensimmäinen lapsi")
    return siblings[idx - 1][4]


def verify_signature(child: Cert, parent_spki: bytes) -> bool:
    from cryptography.exceptions import InvalidSignature
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.primitives.asymmetric import ec, padding, rsa
    from cryptography.hazmat.primitives.serialization import load_der_public_key

    kind_hash = SIG_ALGS.get(child.sig_alg)
    if kind_hash is None:
        raise ChainParseError(f"tukematon allekirjoitusalgoritmi {child.sig_alg}")
    kind, hname = kind_hash
    h = {"sha256": hashes.SHA256(), "sha384": hashes.SHA384(), "sha512": hashes.SHA512()}[hname]
    key = load_der_public_key(parent_spki)
    try:
        if kind == "rsa" and isinstance(key, rsa.RSAPublicKey):
            key.verify(child.signature, child.tbs, padding.PKCS1v15(), h)
        elif kind == "ec" and isinstance(key, ec.EllipticCurvePublicKey):
            key.verify(child.signature, child.tbs, ec.ECDSA(h))
        else:
            return False
    except InvalidSignature:
        return False
    return True


def load_production_roots(path: Path = ROOTS_FILE) -> Dict[str, Cert]:
    """Kiinnitetyt Googlen juuret. Sormenjälki tarkistetaan PEM:stä; ristiriita kaataa."""
    data = json.loads(path.read_text())
    out: Dict[str, Cert] = {}
    for r in data.get("roots", []):
        body = "".join(l for l in r["pem"].strip().splitlines() if not l.startswith("-----"))
        der = base64.b64decode(body)
        if hashlib.sha256(der).hexdigest() != r["sha256"]:
            raise ValueError(f"juuritiedosto ristiriitainen: {r['sha256']}")
        out[r["sha256"]] = parse_cert(der)
    return out


def roots_from_ders(ders: List[bytes]) -> Dict[str, Cert]:
    """Testien luottamusjoukko (synteettinen testijuuri)."""
    return {hashlib.sha256(d).hexdigest(): parse_cert(d) for d in ders}


@dataclass
class ChainResult:
    status: str                 # "ok" | "failed" | "unknown"
    reason: str
    certs: List[Cert] = field(default_factory=list)
    revocation_known: bool = False
    notes: List[str] = field(default_factory=list)


def check_chain(ders: List[bytes], roots: Dict[str, Cert], now: datetime,
                status_entries: Optional[Dict[str, dict]],
                status_fetched: Optional[datetime]) -> ChainResult:
    if not ders or not all(isinstance(d, (bytes, bytearray)) and d for d in ders):
        return ChainResult("unknown", "varmenneketju puuttuu tai tyhjä")
    try:
        certs = [parse_cert(bytes(d)) for d in ders]
    except ChainParseError as e:
        return ChainResult("unknown", f"varmenne ei jäsenny: {e}")
    notes = [f"varmenne {i}: ECDSA-algoritmilla NULL-parametri (sallittu poikkeama)"
             for i, c in enumerate(certs) if c.sig_params_null and c.sig_alg.startswith("1.2.840.10045")]

    last = certs[-1]
    if last.sha256 in roots:
        anchor = roots[last.sha256]
        if not verify_signature(last, anchor.spki):
            return ChainResult("failed", "juuren omaallekirjoitus ei täsmää", certs)
    else:
        anchor = next((r for r in roots.values() if r.subject == last.issuer
                       and _sig_ok(last, r.spki)), None)
        if anchor is None:
            return ChainResult("failed", "ketju ei pääty kiinnitettyyn Googlen juureen", certs)
    for i in range(len(certs) - 1):
        child, parent = certs[i], certs[i + 1]
        if child.issuer != parent.subject:
            # Googlen esimerkki ei vertaa nimiä; oikeat laitteet (Huawei, Xiaomi)
            # jättävät julkaisijasta title-kentän pois. Allekirjoitus ratkaisee.
            notes.append(f"varmenteen {i} julkaisijanimi ≠ varmenteen {i + 1} nimi")
        try:
            ok = verify_signature(child, parent.spki)
        except ChainParseError as e:
            return ChainResult("unknown", f"varmenne {i}: {e}", certs)
        if not ok:
            return ChainResult("failed", f"varmenteen {i} allekirjoitus ei täsmää", certs)
    # Luottamusankkuri on kiinnitetty avain; sen oman varmenteen voimassaoloa ei
    # tarkisteta (RFC 5280 6.1.1 d). Ketjun jokaisen varmenteen voimassaolo tarkistetaan.
    for i, c in enumerate(certs):
        if not (c.not_before <= now <= c.not_after):
            return ChainResult("failed", f"varmenne {i} ei voimassa {now:%Y-%m-%d} "
                               f"({c.not_before:%Y-%m-%d}–{c.not_after:%Y-%m-%d})", certs)

    known = status_entries is not None and status_fetched is not None \
        and timedelta(0) <= now - status_fetched <= STATUS_MAX_AGE
    if status_entries is not None:
        for i, c in enumerate(certs):
            ent = status_entries.get(format(c.serial, "x"))
            if ent and ent.get("status") in ("REVOKED", "SUSPENDED"):
                return ChainResult("failed", f"varmenne {i} {ent['status']} ({ent.get('reason', '?')})",
                                   certs, known, notes)
    return ChainResult("ok", "ketju kiinnitettyyn juureen, allekirjoitukset ja voimassaolo kunnossa",
                       certs, known, notes)


def _sig_ok(c: Cert, spki: bytes) -> bool:
    try:
        return verify_signature(c, spki)
    except ChainParseError:
        return False
