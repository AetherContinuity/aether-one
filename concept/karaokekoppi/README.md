# KaraokeKoppi — Tuotantovalvomo (VPS)

Energiajärjestelmän resilienssivalvomo — WEM-konseptin
tuotantototeutus Docker-pohjaisena VPS-palveluna.

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
