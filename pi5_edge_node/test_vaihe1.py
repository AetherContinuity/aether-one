#!/usr/bin/env python3
"""Vaihe 1 hyväksymistesti (docs/VAIHE1-ENNAKKO.md K1-K8).

Vaatii: swtpm käynnissä ja AK:t 0x81000000 ja 0x81000001 provisioitu:
  bash setup_swtpm.sh && AK_HANDLE=0x81000001 bash setup_swtpm.sh
Ajaa todentajan prosessin sisällä (server.verify_bytes) ilman HTTP:tä;
HTTP-polku testataan erikseen test_client_e2e.py:ssä.

Jokainen tapaus vertaa kaikkia neljää väitettä odotettuun. Yksikin
poikkeama -> exit 1.
"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path

os.environ.setdefault("TPM2TOOLS_TCTI", "swtpm:host=localhost,port=2321")
DATA = tempfile.mkdtemp(prefix="tc_vaihe1_")
os.environ["TRUSTCORE_DATA_DIR"] = DATA

import cbor2  # noqa: E402

from core.trustcore import admin, server  # noqa: E402
from core.trustcore.client import TrustCoreClient, TrustCoreConfig  # noqa: E402
from core.trustcore.crypto import make_attestation_message, quote_hash  # noqa: E402
from core.trustcore.tpm_wrapper import TPMWrapper  # noqa: E402

DEVICES = Path(DATA) / "devices.json"
FAILS: list[str] = []
U, F, P, V, X = "UNKNOWN", "FAILED", "PARTIAL", "VERIFIED", "UNSUPPORTED"


def nonce() -> bytes:
    return bytes.fromhex(server.get_nonce()["nonce"])


def resign(c: TrustCoreClient, b: dict) -> dict:
    """Allekirjoittaa muokatun paketin uudelleen, jotta Q pysyy ehjänä ja A eristyy."""
    msg = make_attestation_message(
        device_id=b["device_id"], policy_id=b["policy_id"], nonce=b["nonce"],
        quote_hash=quote_hash(b.get("tpm_quote") or {}),
        sensor_state_hash=b["sensor_state_hash"], decision_hash=b["decision_hash"])
    b["pqc"]["signature"] = c.pqc.sign(msg)
    return b


def first_pcr_offset(blob: bytes) -> int:
    """PCR0:n arvon sijainti tpm2_quote -o -tiedostossa.

    tpm2-tools sarjallistaa kiinteäkokoiset C-rakenteet: TPML_PCR_SELECTION
    (4 + 16*8 = 132 tavua), u32 listojen määrä, TPML_DIGEST (u32 count,
    16 x TPM2B_DIGEST{u16 size, 64 tavua}). Loppu on täytettä, jota
    tpm2_checkquote ei lue; tiedoston viimeisen tavun turmelu ei siksi
    ole PCR-muutos. Rakenne tarkistetaan, jotta formaatin muutos kaataa
    testin eikä ohjaa turmelua täytteeseen.
    """
    sel_count = int.from_bytes(blob[0:4], "little")
    sel_hash = int.from_bytes(blob[4:6], "little")
    n_lists = int.from_bytes(blob[132:136], "little")
    n_dig = int.from_bytes(blob[136:140], "little")
    size = int.from_bytes(blob[140:142], "little")
    if not (sel_count == 1 and sel_hash == 0x000B and n_lists >= 1 and n_dig >= 1 and size == 32):
        raise SystemExit(f"tpm2_quote -o -formaatti odottamaton: {blob[:144].hex()}")
    return 142


def bundle(c: TrustCoreClient, n: bytes) -> dict:
    return cbor2.loads(c.create_bundle(n, {"t": 1}))


def check(name: str, resp: dict, want: dict) -> None:
    if "status" in resp:
        FAILS.append(f"{name}: vastauksessa on yhteinen status-kenttä (K1)")
    got = {k: resp.get("claims", {}).get(k, {}).get("result") for k in "ABPQ"}
    ok = got == want
    print(f"{'OK  ' if ok else 'FAIL'} {name}: {got}")
    if not ok:
        FAILS.append(f"{name}: odotettu {want}, saatu {got}")
        for k in "ABPQ":
            print(f"       {k}: {resp.get('claims', {}).get(k)}")


def verify(b: dict) -> dict:
    return server.verify_bytes(cbor2.dumps(b))


def main() -> int:
    keys = Path(DATA) / "keys"
    c = TrustCoreClient(TrustCoreConfig(server_url="-", keydir=str(keys)))
    exp = c.export_enrollment(platform="swtpm", tpm_kind="swtpm")
    rec = admin.enroll(DEVICES, exp)
    ALL_U = dict.fromkeys("ABPQ", U)

    # Ulkoinen mittapuu: rekisteröinnin TPM2B_PUBLIC:sta muodostama PEM on
    # tavu tavulta sama kuin tpm2-toolsin oma (tpm2_readpublic -f pem).
    with tempfile.TemporaryDirectory() as td:
        ref = Path(td) / "ak.pem"
        subprocess.run(["tpm2_readpublic", "-c", "0x81000000", "-f", "pem", "-o", str(ref)],
                       check=True, capture_output=True)
        same = ref.read_text() == rec["ak_pem"]
    print(f"{'OK  ' if same else 'FAIL'} AK-PEM = tpm2_readpublic -f pem")
    if not same:
        FAILS.append("rekisteröinnin AK-PEM poikkeaa tpm2-toolsin PEM:stä")

    # Positiivinen tapaus
    check("positiivinen (swtpm)", verify(bundle(c, nonce())), {"A": P, "B": X, "P": X, "Q": V})

    # K8 negatiivikontrollit
    c_notpm = TrustCoreClient(TrustCoreConfig(server_url="-", keydir=str(keys)))
    c_notpm.tpm, c_notpm.tpm_init_error = None, "testi: TPM poistettu"
    r = verify(bundle(c_notpm, nonce()))
    check("quote puuttuu", r, {"A": U, "B": X, "P": X, "Q": V})
    if "testi: TPM poistettu" not in r["claims"]["A"]["reason"]:
        FAILS.append("quote puuttuu: tpm_error ei näy A:n syyssä")

    b = bundle(c, nonce())
    s = bytearray(b["tpm_quote"]["sig"]); s[-1] ^= 1; b["tpm_quote"]["sig"] = bytes(s)
    check("quote-allekirjoitus turmeltu", verify(resign(c, b)), {"A": F, "B": X, "P": X, "Q": V})

    c_other = TrustCoreClient(TrustCoreConfig(server_url="-", keydir=str(keys)))
    c_other.tpm = TPMWrapper(ak_handle="0x81000001")
    check("toinen AK", verify(bundle(c_other, nonce())), {"A": F, "B": X, "P": X, "Q": V})

    n = nonce()
    b = bundle(c, n)
    b["tpm_quote"] = c.tpm.quote(os.urandom(32))  # type: ignore[union-attr]
    check("väärä quote-nonce", verify(resign(c, b)), {"A": F, "B": X, "P": X, "Q": V})

    b = bundle(c, nonce())
    p = bytearray(b["tpm_quote"]["pcrs"])
    p[first_pcr_offset(p)] ^= 1
    b["tpm_quote"]["pcrs"] = bytes(p)
    check("muutettu PCR (PCR0)", verify(resign(c, b)), {"A": F, "B": X, "P": X, "Q": V})

    b = bundle(c, os.urandom(32))
    check("tuntematon nonce", verify(b), ALL_U)

    b = bundle(c, nonce())
    verify(b)
    check("käytetty nonce (toisto)", verify(b), ALL_U)

    c_new = TrustCoreClient(TrustCoreConfig(server_url="-", keydir=str(Path(DATA) / "keys2")))
    check("rekisteröimätön laite", verify(bundle(c_new, nonce())), ALL_U)

    b = bundle(c, nonce())
    s = bytearray(b["pqc"]["signature"]); s[5] ^= 1; b["pqc"]["signature"] = bytes(s)
    check("ML-DSA turmeltu", verify(b), {"A": P, "B": X, "P": X, "Q": F})

    b = bundle(c, nonce())
    del b["pqc"]["signature"]
    check("ML-DSA puuttuu", verify(b), {"A": P, "B": X, "P": X, "Q": U})

    # ML-DSA kattaa quoten: quoten vaihto ilman uudelleenallekirjoitusta -> Q FAILED
    b = bundle(c, nonce())
    b2 = bundle(c, nonce())
    b["tpm_quote"] = b2["tpm_quote"]
    check("quote vaihdettu, ei uudelleenallekirjoitusta", verify(b), {"A": F, "B": X, "P": X, "Q": F})

    # Rajoittamaton AK -> rekisteröinti hylätään (K2)
    env = dict(os.environ)
    with tempfile.TemporaryDirectory() as td:
        t = Path(td)
        for cmd in (
            ["tpm2_createprimary", "-C", "o", "-c", str(t / "p.ctx"), "-Q"],
            ["tpm2_create", "-C", str(t / "p.ctx"), "-G", "rsa", "-u", str(t / "k.pub"),
             "-r", str(t / "k.priv"), "-Q"],
            ["tpm2_flushcontext", "-t"],
        ):
            subprocess.run(cmd, check=True, capture_output=True, env=env)
        bad = dict(exp, device_id="rajoittamaton", ak_public_tss_hex=(t / "k.pub").read_bytes().hex())
    try:
        admin.enroll(DEVICES, bad)
        FAILS.append("rajoittamaton AK: rekisteröinti hyväksyttiin")
        print("FAIL rajoittamaton AK hyväksyttiin")
    except admin.EnrollError as e:
        ok = "restricted puuttuu" in str(e) and "decrypt asetettu" in str(e)
        print(f"{'OK  ' if ok else 'FAIL'} rajoittamaton AK hylätty: {e}")
        if not ok:
            FAILS.append(f"rajoittamaton AK: väärä syy: {e}")

    # Vajaa vienti -> hylätään
    try:
        admin.enroll(DEVICES, {k: v for k, v in exp.items() if k != "ak_public_tss_hex"} | {"device_id": "vajaa"})
        FAILS.append("vajaa vienti hyväksyttiin")
    except admin.EnrollError as e:
        print(f"OK   vajaa vienti hylätty: {e}")

    print()
    if FAILS:
        print(f"VAIHE 1: {len(FAILS)} poikkeamaa")
        for f in FAILS:
            print("  -", f)
        return 1
    print("VAIHE 1: kaikki tapaukset odotetusti")
    return 0


if __name__ == "__main__":
    sys.exit(main())
