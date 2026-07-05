# KaraokeKoppi — Tuotantovalvomo (VPS)

Energiajärjestelmän resilienssivalvomo — WEM-konseptin
tuotantototeutus Docker-pohjaisena VPS-palveluna.

**HUOM (2026-07-05):** `l5_core/` ja `l6_decision_matrix/` ovat tähän
tallennettu jäljennös (snapshot) paikallisista zip-paketeista
(`AO-DECISION-L5_CORE.zip`, `AO-DECISION-L6_DECISION_MATRIX.zip`).
Elävä, ajossa oleva versio asuu erillisessä VPS-repossa jolla on DASC-
rakenne — TÄMÄ ei ole se repo. Koodi testattu ja todennettu toimivaksi
tässä sessiossa (`case_manager.py`, `decision_matrix.py`,
`action_simulator.py` ajettu suoraan, tulokset täsmäävät). `weather_fmi.py`
ei testattu elävänä (FMI-verkkopääsy ei käytettävissä tässä ympäristössä).
`delta_index`-arvot `decision_matrix.py`:ssä on itse merkitty
kalibroimattomiksi lähtöarvioiksi, ei mitattua dataa.

## Arkkitehtuuri

```
SSA (Situational Awareness)    → Snapshot-kerros
  - FMI Time-Lock (sää → riski)   Helsinki/Kuopio/Oulu/Rovaniemi
  - Grid signals (taajuus, reservit)
  - Locks: Reserve / Time / Governance

Hub (Orchestrator)             → Päätöskerros
  - Case Manager (debounce 10min)
  - Recommendation Engine
  - Email-hälytykset

Dashboard                      → Visualisointikerros
  - Resilience Index
  - Lock-tilat
  - Active cases
```

## Yhteys Aether One -kehykseen

KaraokeKoppi = käytännön testialusta Lex Resiliens -mallille:
- Locks = LR-dimensiot (Reserve≈R, Time≈E, Governance≈S)
- Resilience Index = KRI_X käytännössä
- Case Manager = trustcore_step() käytännössä

## Tila

Aktiivinen deployment — L5-integraatio valmis (FMI + Case Manager).
Seuraava: Decision Matrix -integraatio.
