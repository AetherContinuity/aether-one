# Resilienssi-indikaattori – Visuaalinen yhteenveto

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                   RESILIENSSI-INDIKAATTORI                                  │
│         Päätöksenteon varhainen varoitusjärjestelmä                         │
└─────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────┐
│ TIETOLÄHTEET (avoimet rajapinnat)                                         │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐       │
│  │   FINGRID API    │  │   FMI WEATHER    │  │  HISTORIADATA    │       │
│  ├──────────────────┤  ├──────────────────┤  ├──────────────────┤       │
│  │ • Taajuus        │  │ • Lämpötila      │  │ • Trendit        │       │
│  │ • Tuotanto       │  │ • Tuuli          │  │ • Poikkeamat     │       │
│  │ • Kulutus        │  │ • Ennusteet      │  │ • Vertailu       │       │
│  │ • Reservit       │  │ • 4 kaupunkia    │  │                  │       │
│  └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘       │
│           │                     │                      │                 │
│           └──────────────┬──────┴──────────────────────┘                 │
│                          │                                               │
└──────────────────────────┼───────────────────────────────────────────────┘
                           ▼
┌───────────────────────────────────────────────────────────────────────────┐
│ ANALYYSIMOOTTORIT                                                         │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │ TIME-LOCK (Sään vaikutus)                                           │ │
│  ├─────────────────────────────────────────────────────────────────────┤ │
│  │ Input: Lämpötila + tuuli (4 kaupunkia)                             │ │
│  │ Laskenta: worst-2-of-4 keskiarvo                                   │ │
│  │ Output: OK / WEAK / CRITICAL + riski 0..1                          │ │
│  │ Tulkinta: Kylmä + tyyntä = kriisi (ei lämmitystä eikä tuulivoimaa) │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │ RESERVE-LOCK (Fyysinen kesto)                                       │ │
│  ├─────────────────────────────────────────────────────────────────────┤ │
│  │ Input: Reservit + kulutus                                          │ │
│  │ Laskenta: reserve_margin = reservit / kulutus                      │ │
│  │ Output: OK / WEAK / CRITICAL                                       │ │
│  │ Tulkinta: Riittääkö puskuria häiriöille?                           │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
│                                                                           │
│           ┌───────────────────────────────────────────┐                  │
│           │ RESILIENCE INDEX (Kokonaisarvio)          │                  │
│           ├───────────────────────────────────────────┤                  │
│           │ Yhdistää kaikki lukot 0..1 asteikolla     │                  │
│           │ • 0.85-1.0  = Normaali                    │                  │
│           │ • 0.70-0.84 = Heikkenevä                  │                  │
│           │ • <0.70     = Kriittinen                  │                  │
│           └─────────────────┬─────────────────────────┘                  │
│                             │                                            │
└─────────────────────────────┼────────────────────────────────────────────┘
                              ▼
┌───────────────────────────────────────────────────────────────────────────┐
│ CASE MANAGER (Älykäs eskalaatio)                                         │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  Triggerit:                          Anti-spam:                          │
│  ┌────────────────────────────┐      ┌────────────────────────────┐     │
│  │ 1. Indeksi putoaa ≥7%      │      │ • Max 1 hälytys / 10min    │     │
│  │ 2. Mikä tahansa lukko      │  →   │ • State management         │     │
│  │    muuttuu CRITICAL        │      │ • Ei false positiveja      │     │
│  └────────────────────────────┘      └────────────────────────────┘     │
│                             │                                            │
│                             ▼                                            │
│              ┌──────────────────────────────┐                            │
│              │ CASE-1738245932 käynnistyy   │                            │
│              │ Syy: INDEX_DROP_0.08 +       │                            │
│              │      LOCK_CRITICAL           │                            │
│              └──────────────┬───────────────┘                            │
│                             │                                            │
└─────────────────────────────┼────────────────────────────────────────────┘
                              ▼
┌───────────────────────────────────────────────────────────────────────────┐
│ HÄLYTYKSET & VISUALISOINTI                                                │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐       │
│  │   SÄHKÖPOSTI     │  │   DASHBOARD      │  │   AUDIT LOG      │       │
│  ├──────────────────┤  ├──────────────────┤  ├──────────────────┤       │
│  │ Kriisihälytys    │  │ Grafana          │  │ JSON Lines       │       │
│  │ Päiväraportti    │  │ Reaaliaikaiset   │  │ Historia         │       │
│  │ Case ID + syy    │  │ kuvaajat         │  │ Trendianalyysi   │       │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘       │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────┐
│ KRIITTINEN PERIAATE                                                       │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ╔═══════════════════════════════════════════════════════════════════╗   │
│  ║  JÄRJESTELMÄ EI TEE PÄÄTÖKSIÄ                                     ║   │
│  ║  Se ei ohjaa verkkoa. Se ei anna käskyjä.                         ║   │
│  ║                                                                   ║   │
│  ║  Ainoa tehtävä:                                                   ║   │
│  ║  1. Havaita heikkenevä kehityssuunta                              ║   │
│  ║  2. Ilmoittaa siitä riittävän aikaisin                            ║   │
│  ║  3. Parantaa päätöksentekijöiden tilannetietoisuutta              ║   │
│  ╚═══════════════════════════════════════════════════════════════════╝   │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────┐
│ VERTAUS: JÄRJESTELMÄ TOIMII KUIN...                                       │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  🔥 Palovaroitin rakennuksessa                                            │
│     → Ei sammuta tulipaloa, mutta varoittaa ajoissa                      │
│                                                                           │
│  ⚠️  Varoitusvalo kojelaudassa                                            │
│     → Ei ohjaa autoa, mutta kertoo ongelmista ennen rikkoutumista        │
│                                                                           │
│  💓 Sydänmonitori tehohoidossa                                            │
│     → Ei hoida potilasta, mutta havaitsee sykkeen muutokset              │
│                                                                           │
│  Resilienssi-indikaattori tekee saman sähköjärjestelmän                  │
│  reagointikyvylle: varoittaa ennen kuin kriisi ehtii eskaloitua.         │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────┐
│ YHDEN LAUSEEN TIIVISTELMÄ                                                 │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  "Työkalu, joka arvioi pysyykö päätöksentekokyky mukana silloin,         │
│   kun sähköjärjestelmän olosuhteet heikkenevät nopeasti."                │
│                                                                           │
│  Ei lisää hallintoa. Ei lisää byrokratiaa.                                │
│  Lisää ennakoivaa tilannetietoisuutta.                                    │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
```

---

## Esimerkkiskenaario: Talvipäivä 2026

```
Aika: 06:00
┌─────────────────────────────────────────────────────────────┐
│ TILANNE:                                                    │
│ • Rovaniemi: -28°C, tuuli 1.2 m/s                           │
│ • Oulu: -24°C, tuuli 2.1 m/s                                │
│ • Lämmitystarve korkea, tuulivoima hiljaa                   │
│ • Reservit: 450 MW (normaali ~800 MW)                       │
│                                                             │
│ RESILIENSSI-INDIKAATTORI:                                   │
│ • Time Lock: CRITICAL (worst-2: -26°C, 1.6 m/s)             │
│ • Reserve Lock: WEAK (450 MW / 9000 MW = 5%)                │
│ • Index: 0.65 (lasku 0.92 → 0.65 = delta 0.27)              │
│                                                             │
│ TOIMENPIDE:                                                 │
│ → CASE-1738245932 käynnistyy                                │
│ → Sähköposti päättäjille: "Kriittinen tilanne, suositus:   │
│    harkitse kysyntäjoustoa ja varavoiman käynnistystä"      │
└─────────────────────────────────────────────────────────────┘

Aika: 06:15
┌─────────────────────────────────────────────────────────────┐
│ PÄÄTÖKSENTEKIJÄT:                                           │
│ • Näkevät varhaisvaroituksen                                │
│ • Aikaa reagoida ennen kuin taajuus tippuu                  │
│ • Voivat aktivoida kysyntäjouston                           │
│ • Voivat käynnistää varavoimaa ennakoivasti                 │
└─────────────────────────────────────────────────────────────┘

Aika: 07:00
┌─────────────────────────────────────────────────────────────┐
│ TOIMENPITEIDEN JÄLKEEN:                                     │
│ • Kysyntäjousto aktivoitu: -200 MW                          │
│ • Varavoima käynnistetty: +300 MW                           │
│ • Reservit: 450 → 750 MW                                    │
│ • Index: 0.65 → 0.78 (paranee)                              │
│                                                             │
│ LOPPUTULOS:                                                 │
│ → Kriisi vältetty ennen kuin se ehti alkaa                  │
│ → Ei sähkökatkoja                                           │
│ → Päätöksenteko ehti reagoida                               │
└─────────────────────────────────────────────────────────────┘
```
