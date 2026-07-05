#!/usr/bin/env python3
"""KaraokeKoppi™ SMTP/Gmail -yhteystesti

Aja VPS:llä projektin juuressa:
  python3 test_mail.py

Vaatii .env:
  SMTP_SERVER=smtp.gmail.com
  SMTP_PORT=587
  SMTP_USER=...
  SMTP_PASS=... (Google App Password, 16 merkkiä)
  REPORT_RECIPIENT=ruotsalainen.marko@gmail.com
"""

import os
import sys
from dotenv import load_dotenv

load_dotenv()

try:
    from hub.notifier import send_email
except Exception as e:
    print("❌ import hub.notifier.send_email epäonnistui")
    print("   Aja tämä KaraokeKoppi-projektin juuressa.")
    print(f"   Virhe: {e}")
    sys.exit(1)


def _req(name: str) -> str:
    v = os.getenv(name)
    if not v:
        raise RuntimeError(f"Puuttuva env: {name}")
    return v


def run_test() -> None:
    recipient = _req("REPORT_RECIPIENT")
    smtp_server = _req("SMTP_SERVER")
    smtp_port = _req("SMTP_PORT")

    subject = "KARAOKEKOPPI™ - Yhteystesti"
    body = f"""Tämä on automaattinen testi-ilmoitus KaraokeKoppi™ Orchestratorilta.

Aika: {os.popen('date').read().strip()}
Status: Sähköpostirajapinta aktivoitu.

Jos sait tämän viestin, järjestelmä on valmis lähettämään kriisihälytyksiä
ja resilienssiraportteja osoitteeseen: {recipient}

Lex Resiliens Node 001: ONLINE
"""

    print("--- Sähköpostiyhteyden testaus ---")
    print(f"Vastaanottaja: {recipient}")
    print(f"SMTP: {smtp_server}:{smtp_port}")

    send_email(subject, body)
    print("\n✅ Testiviesti lähetetty onnistuneesti!")
    print("Tarkista postilaatikko (ja roskaposti).")


if __name__ == "__main__":
    try:
        run_test()
    except Exception as e:
        print("\n❌ Testi epäonnistui!")
        print(f"Virhe: {e}")
        print("\nGmail-vinkki: SMTP vaatii yleensä App Passwordin (2FA + sovellussalasana).")
        sys.exit(2)
