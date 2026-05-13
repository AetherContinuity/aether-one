# Decision Matrix — Kriisipäätöksenteon moottori

Muuttaa valvomon hälytysnäytöstä päätöksenteon työkaluksi.

## Toimintaperiaate

Kriisi (index < 0.75) → 3 toimenpidesuositusta automaattisesti:

| Suositus | Toimenpide | Δ indeksi | Aika | Kustannus |
|----------|------------|-----------|------|-----------|
| 1 | Kysyntäjousto + Varavoima | +0.18 | 60 min | 250k € |
| 2 | Varavoima | +0.12 | 60 min | 200k € |
| 3 | Kysyntäjousto + Viestintä | +0.07 | 30 min | 15k € |

Jokainen suositus sisältää: kustannus, henkilöstö,
poliittinen riski, tekninen riski, lock-vaikutukset.

## Moduulit

- `decision_matrix_full.py` — ACTIONS-tietokanta
- `action_simulator.py` — vaikutuslaskenta
- `recommendation_engine.py` — priorisointi + riskit

## Integraatio

KaraokeKoppi Hub → Case trigger → Recommendation Engine
→ suositukset sähköpostiin + dashboardiin
