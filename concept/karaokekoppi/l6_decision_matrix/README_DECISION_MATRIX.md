# KaraokeKoppi™ L6 – Decision Matrix (Drop‑in)

## Mitä tämä lisää
- **Decision Matrix**: toimenpideluettelo + eksplisiittiset vaikutusarviot
- **Simulaattori**: before → after (index + locks)
- **Dashboard‑paneeli**: valitse toimenpide ja näe vaikutus
- **test_mail.py**: puhdas SMTP/Gmail-testi

Tämä on tarkoituksella **deterministinen ja muokattava**. Kalibroi myöhemmin audit-datalla.

---

## 1) Kopioi tiedostot projektiin

Projektin juuressa:

```bash
# Hub
cp -v AO-DECISION-L6_DECISION_MATRIX/hub/app/decision_matrix.py  ./hub/app/
cp -v AO-DECISION-L6_DECISION_MATRIX/hub/app/action_simulator.py ./hub/app/

# SMTP-testi
cp -v AO-DECISION-L6_DECISION_MATRIX/tools/test_mail.py ./test_mail.py

# Dashboard (liitä sisältö sopivaan paikkaan)
# jos sinulla on esim. frontend/index.html, liitä actions_panel.html sen loppupuolelle
```

---

## 2) Lisää Hubiin 2 endpointia

Muokkaa: `hub/app/main.py`

Lisää importit:

```python
from app.decision_matrix import get_actions, to_public_dict
from app.action_simulator import simulate_action
```

Lisää reitit (FastAPI):

```python
# Listaa Decision Matrix -toimenpiteet
@app.get("/api/v2/actions")
async def list_actions():
    return {"actions": [to_public_dict(a) for a in get_actions()]}

# Simuloi valittu toimenpide
@app.get("/api/v2/simulate")
async def simulate(action_id: str):
    # Oletus: sinulla on jokin viimeisin snapshot sanakirjana.
    # Jos käytät eri nimeä kuin LATEST_STATE, vaihda tähän.
    global LATEST_STATE
    return simulate_action(LATEST_STATE, action_id)
```

### Snapshot-vaatimus
Simulaattori odottaa avaimet:
- `metrics.resilience_index`
- `locks.Reserve`, `locks.Inertia`, `locks.Time`, `locks.Governance`

Jos avaimet poikkeavat, muokkaa `simulate_action()`.

---

## 3) Liitä dashboard-paneeli

Avaa `AO-DECISION-L6_DECISION_MATRIX/dashboard/partials/actions_panel.html` ja liitä sisältö dashboardiin.
Paneeli kutsuu:
- `GET /api/v2/actions`
- `GET /api/v2/simulate?action_id=...`

---

## 4) Käynnistä uudelleen

```bash
docker compose up -d --build
```

---

## 5) Testaa sähköposti

`.env`:

```env
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=ruotsalainen.marko@gmail.com
SMTP_PASS=APP_PASSWORD_16_CHARS
REPORT_RECIPIENT=ruotsalainen.marko@gmail.com
```

Aja:

```bash
python3 test_mail.py
```

**Gmail**: tavallinen salasana ei yleensä käy SMTP:ssä → käytä **App Passwordia** (vaatii 2FA).
