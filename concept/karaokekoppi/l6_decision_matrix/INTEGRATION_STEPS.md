# KaraokeKoppi™ L6 – Decision Matrix (drop‑in)

Tämä paketti lisää valvomoon **”Mitä jos…?”** ‑paneelin ja 2 uutta API-endpointia.

## 1) Kopioi tiedostot

Pura zip ja kopioi:

- `hub/app/decision_matrix.py`
- `hub/app/action_simulator.py`
- `dashboard/partials/actions_panel.html`

Repojuuressa:

```bash
unzip AO-DECISION-L6_DECISION_MATRIX.zip -d /tmp/l6
cp /tmp/l6/hub/app/decision_matrix.py hub/app/
cp /tmp/l6/hub/app/action_simulator.py hub/app/
mkdir -p dashboard/partials
cp /tmp/l6/dashboard/partials/actions_panel.html dashboard/partials/
```

## 2) Lisää endpointit hubiin

Avaa `hub/app/main.py` ja lisää importit ylös:

```python
from hub.app.decision_matrix import list_actions
from hub.app.action_simulator import run_simulation
```

Lisää nämä endpointit (esim. muiden `/api/v2/*` reittien joukkoon):

```python
@app.get("/api/v2/actions")
def api_actions():
    return list_actions()

@app.get("/api/v2/simulate")
def api_simulate(action_id: str):
    # käytetään viimeisintä snapshotia (sama kuin streamissä)
    snap = STATE.get("last_snapshot") or {}
    return run_simulation(snap, action_id)
```

**Huom:** jos sinulla on eri STATE-muuttuja, käytä sitä mistä dashboard-streamkin saa datan.

## 3) Upota paneeli dashboardiin

Jos sinulla on `dashboard/index.html`, lisää haluamaasi kohtaan:

```html
<!-- Decision Matrix -->
<div class="mb-4">
  <!-- include partial file contents here, tai copy-paste -->
</div>
```

Helpoin: copy‑paste `dashboard/partials/actions_panel.html` sisällön suoraan `index.html`:ään.

## 4) Rakenna ja käynnistä

```bash
docker compose down
docker compose up -d --build
```

## Testi

- Avaa dashboard
- Paina **Kysyntäjousto** → näet KRI‑X ja lukot ”ennen → jälkeen”

## Muokkaus

Muokkaa matriisia tiedostossa `hub/app/decision_matrix.py`:

- `index_delta` (0–1 skaala)
- lukkojen stepit `reserve/time_lock/governance` (-2..+2)

