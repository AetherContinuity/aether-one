# Lex Resiliens (LR) — Päätöksentekokyvyn stressitesti

Hallintokehys joka erottaa toisistaan:
- Tekninen pakko
- Poliittinen arvovalinta  
- Institutionaalinen kykenemättömyys tehdä päätös ajoissa

> "Päätöksen tekemättä jättäminen on myös päätös — ja sen seuraukset ovat fyysisiä, eivät teoreettisia."

## Menetelmän ydin

Kriisiskenaariota analysoidaan pakotetusti:

1. Mikä on ensimmäinen hallitsematon vika?
2. Mikä on **point of no return** ja miten se mitataan?
3. Mikä on aikaikkuna jonka jälkeen päätöksillä ei ole vaikutusta?
4. Mikä on **yksi (1)** rajattu interventio joka estää tämän vian?
5. Mitä tämä interventio **ei** ratkaise?

Rakenne kieltää useiden samanaikaisten toimenpiteiden esittämisen.

## Resilienssidimensiot

| Dimensio | Kuvaus | LR2030-lukko |
|----------|--------|--------------|
| **R** | Resource Resilience — energia, materiaali, logistiikka | RSM, RRM |
| **S** | Social & Systemic — instituutiot, luottamus, oikeudenmukaisuus | IRS |
| **E** | Ecological & Economic — ekologia, talous, pitkäjänteisyys | LRM |

## KRI_X

```
KRI_X = (R + S + E) / 3    [asteikko -3 … +3]
```

## LR2030 — "Structure before will"

Neljä automaattista rakenteellista lukkoa:

| Lukko | Sääntö | Ylityksen seuraus |
|-------|--------|-------------------|
| **RSM** | Velka max +1.5% BKT/v | VRF-96h jäädytys |
| **LRM** | Kriisikulut → 2020-taso + inflaatio | S-score ≥ 68 vaaditaan |
| **RRM** | Korkomenot max 4% budjetista | VRF-96h + RAP-priorisointi |
| **IRS** | Max 20% alijäämästä tulevien sukupolvien maksettavaksi | R-S-E avg ≥ 0 vaaditaan |

## Mekanismit

- **VRF-96h** — 96 tunnin päätösjäädytys ylityksestä
- **RAP** — Resilience Action Protocol, priorisoitu toimenpidelista
- **CWE-sykli** — Orientation → Work → Reflection

## Tavoite 2030 (Suomi)

- Valtion velka < 170 mrd €
- Korkomenot 3-4 mrd €/v
- Palvelut vakautuvat
- Kriisivalmius palautuu

## Yhteys ACI-kehykseen

| LR | ACI |
|----|-----|
| Point of no return | TN-014 endurance failure |
| VRF-96h | D_p:n minimivaatimus |
| KRI_X = (R+S+E)/3 | D_total = w_s·D_s + w_m·D_m + w_g·D_g |
| IRS sukupolvijärjestys | SM-001 compound risk |

## Toteutukset

- [`framework/`](framework/) — lr-open-framework v1.0 (Python + JSON)
- Python metacore: `src/aether_core/lr_engine.py`
- C-kernel: `trustcore.h` / `trustcore.c`
- VPS: KaraokeKoppi (Locks = LR-dimensiot käytännössä)

## Resilienssikaari

Kansalaisohjelma joka toteuttaa LR-periaatteet:
- FRG-solmut (hajautettu energia + lämpö)
- 72-96h palvelujatkuvuus kunnille
- Sama arkkitehtuuri kuin SM-003:n SGFA
