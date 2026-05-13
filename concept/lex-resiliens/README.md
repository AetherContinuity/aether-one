# Lex Resiliens (LR) — Resilienssimittausjärjestelmä

Kolmiulotteinen resilienssimalli joka arvioi päätöksiä tai järjestelmiä
kolmella akselilla.

## Dimensiot

| Dimensio | Kuvaus | Painotus moodissa |
|----------|--------|-------------------|
| **R** | Rakenteellinen — kestävyys, suunnitelma, budjetti | ENGINEER |
| **S** | Sosiaalinen — yhteisö, oikeudenmukaisuus, vastuu | PHILO |
| **E** | Ekologinen/luova — ympäristö, pitkäjänteisyys | LEX |

## KRI_X

```
KRI_X = (R + S + E) / 3
```

- ≥ 0.80 → korkea resilienssi
- ≥ 0.60 → keskitasoinen
- < 0.60 → heikko — Lex Lock Alert ⚠️

## Moodit

| Moodi | Painotus | Käyttötapaus |
|-------|----------|--------------|
| ENGINEER | R-painotteinen | Tekninen arviointi |
| PHILO | S/E-painotteinen | Eettinen arviointi |
| LEX | Legitimiteetti | Hallinnollinen |
| KuopioCore | Tasapainoinen | Oletus |

## Toteutukset

- Python: `src/aether_core/lr_engine.py` (metacore)
- C: `trustcore.h` / `trustcore.c` (v1.0 kernel)
- Hardware: TrustCore NX SoC (tavoite)

## Yhteys ACI:hin

Sama rakenne kuin ACI:n TN-014:
```
D_total = w_s·D_s + w_m·D_m + w_g·D_g  (ACI hydrologinen)
KRI_X   = (R + S + E) / 3              (Lex Resiliens)
```
Eri konteksti, sama aggregaatiologiikka.
