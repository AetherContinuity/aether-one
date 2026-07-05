# Resilienssi-indikaattori – Tekninen liite

## Yleiskuvaus

Resilienssi-indikaattori on työkalukokonaisuus, joka arvioi sähköjärjestelmän operatiivisen tilannekuvan ja päätöksentekokyvyn suhdetta reaaliajassa. Järjestelmä ei toimi verkko-operaattorina eikä tee päätöksiä, vaan toimii päätöksenteon tukijärjestelmänä.

---

## Arkkitehtuuri

### Tietolähteet (kaikki avoimia rajapintoja)

**1. Sähköjärjestelmän tila:**
- Fingrid Open Data API
  - Taajuus (Hz)
  - Tuotanto ja kulutus (MW)
  - Sähkövarastot ja reservit
  - Tuonti/vienti (MW)
  - Pohjoismainen sähköpörssi

**2. Sääolosuhteet:**
- FMI (Ilmatieteen laitos) WFS-rajapinta
  - Lämpötila (°C) useasta mittauspisteestä
  - Tuulen nopeus (m/s)
  - Sääennusteet
- Monipiste-mittaus (esim. Helsinki, Kuopio, Oulu, Rovaniemi)

**3. Historiadata:**
- Oma audit-loki (JSON Lines)
- Trendianalyysi ja poikkeamien tunnistus

---

## Laskentalogiikat

### 1. Time-Lock (Sään vaikutus resilienssiin)

**Periaate:** Arvioi sääolosuhteiden vaikutusta järjestelmän kantokykyyn.

**Laskenta:**
```
Kerätään data N kaupungista (esim. N=4)
Järjestetään lämpötilat ja tuulet suuruusjärjestykseen
Lasketaan "worst-2-of-N" keskiarvo:
  - t_med = (T_min1 + T_min2) / 2
  - w_med = (W_min1 + W_min2) / 2

Riskilaskenta (0..1 asteikolla):
  - t_risk = min(1.0, max(0.0, (0 - t_med) / 25))
  - w_risk = min(1.0, max(0.0, (10 - w_med) / 10))
  
Yhdistetty riski:
  - time_p = 0.6 * t_risk + 0.4 * w_risk

Tila-arviointi:
  - CRITICAL: w_med < 3.0 m/s JA t_med < -15°C
  - WEAK: w_med < 5.0 m/s TAI t_med < -10°C
  - OK: muut tilanteet
```

**Perustelut:**
- Worst-2-of-N on resistentti yksittäisille mittausvirheille
- Tunnistaa alueelliset kriisit (esim. koko Pohjois-Suomi)
- Lämpötila painotettu 60% (kuormituksen kasvu)
- Tuuli painotettu 40% (tuulivoiman saatavuus)

---

### 2. Reserve Lock (Järjestelmän fyysinen kesto)

**Periaate:** Arvioi käytettävissä olevien reservien riittävyyttä suhteessa kulutukseen.

**Laskenta:**
```
Haetaan:
  - Kulutus (MW)
  - Reservit (MW)
  - Tuotantokapasiteetti (MW)

Lasketaan:
  - reserve_margin = reservit / kulutus
  - capacity_ratio = tuotanto / kulutus

Tila-arviointi:
  - CRITICAL: reserve_margin < 0.05 (alle 5%)
  - WEAK: reserve_margin < 0.10 (alle 10%)
  - OK: reserve_margin >= 0.10
```

---

### 3. Resilience Index (Kokonaisindeksi)

**Periaate:** Yhdistää kaikki lukot yhdeksi numeeriseksi indikaattoriksi.

**Laskenta:**
```
Jokaiselle lukolle annetaan arvo:
  - OK = 1.0
  - WEAK = 0.7
  - CRITICAL = 0.3

Resilienssi-indeksi:
  - index = keskiarvo(kaikki lukot)
  
Esim:
  - Reserve: WEAK (0.7)
  - Time: CRITICAL (0.3)
  - Governance: OK (1.0)
  → index = (0.7 + 0.3 + 1.0) / 3 = 0.67
```

**Tulkinta:**
- 0.85-1.0: Normaali tilanne
- 0.70-0.84: Heikkenevä resilienssi
- <0.70: Kriittinen tilanne

---

### 4. Case Manager (Eskalaatiologiikka)

**Periaate:** Päättää milloin hälytysjärjestelmä aktivoituu.

**Triggerit:**
```
1. Indeksin pudotus ≥ 0.07 (7%)
   - Esim: 0.92 → 0.84 = delta 0.08 → TRIGGER

2. Mikä tahansa lukko muuttuu CRITICAL
   - Esim: Time: OK → CRITICAL → TRIGGER

3. Debounce: Max 1 hälytys / 10 min
   - Estää spämmin ja false positivit
```

**State Management:**
```
Järjestelmä muistaa:
  - Viimeisimmän indeksin
  - Viimeisimmän hälytyksen ajan
  - Nykyisen case ID:n (esim. CASE-1738245932)

Näin vältytään:
  - Samasta tilanteesta toistuvilta hälytyksiltä
  - Pienistä pomppimisista aiheutuvilta false positiveilta
  - Päätöksenteon kuormittamiselta turhilla hälytyksillä
```

---

## Tekninen toteutus

### Komponentit

**1. SSA (Sensor & Situational Awareness)**
- Hakee datan API:sta 30-60s välein
- Suorittaa Time-Lock ja Reserve Lock laskennat
- Tallentaa snapshot JSON-muodossa

**2. Hub (Governance & Analysis)**
- Lukee SSA:n snapshotit
- Laskee Resilience Index
- Suorittaa Case Manager -logiikan
- Lähettää hälytykset (sähköposti, webhook, jne.)

**3. Dashboard (Visualisointi)**
- Grafana tai vastaava
- Reaaliaikaiset kuvaajat
- Historiadata ja trendit

**4. Audit Log**
- JSON Lines -muotoinen loki
- Kaikki snapshots tallennetaan
- Mahdollistaa jälkikäteisanalyysin

---

## Rajapinnat

### Input
- Fingrid Open Data API (REST)
- FMI WFS (XML/GML)
- (Valinnainen) Muut datalähteet

### Output
- JSON snapshot (sisäinen)
- Prometheus metrics (monitoring)
- SMTP (hälytykset)
- (Valinnainen) Webhook, Slack, jne.

---

## Skaalautuvuus ja luotettavuus

**Vikasietokyky:**
- Jos FMI ei vastaa → Time-Lock = UNKNOWN, ei hylätä koko analyysiä
- Jos yksi mittauspiste puuttuu → worst-2-of-3 toimii yhä
- Jos Fingrid API epäonnistuu → viimeisin snapshot säilyy

**Suorituskyky:**
- Laskenta-aika: <1s per snapshot
- Muistin käyttö: <100 MB
- CPU: <5% (idle), <20% (aktiivinen laskenta)

**Datamäärä:**
- Snapshot-koko: ~2 KB
- Audit-logi kasvu: ~6 KB/min (~8.6 MB/vrk)
- Suositus: Arkistointi 30 vrk välein

---

## Validointi

### Testausprotokolla

**1. Yksikkötestit:**
- Time-Lock laskenta eri sääolosuhteilla
- Case Manager triggerit eri skenaarioissa
- Reserve Lock laskenta eri reservi-tasoilla

**2. Integrointitestit:**
- API-kutsujen toimivuus
- Snapshot-muodostus ja tallennus
- Hälytysjärjestelmän toiminta

**3. End-to-end testit:**
- Simuloidut kriisit
- Historiallisten kriisien jälkianalyysi (esim. talvi 2021)
- Vertailu tunnettuihin tapahtumiin

---

## Rajoitukset ja jatkokehitys

### Tunnetut rajoitukset
- Ei huomioi kaikkia verkon topologisia rajoitteita
- Ei sisällä yksityiskohtaista siirtoverkon analyysiä
- Sääennuste on FMI:n varassa (ei omaa ennustemallia)

### Kehityskohteet
- Decision Matrix (toimenpiteiden vaikutusten simulointi)
- LLM-integraatio (strateginen analyysi)
- Koneoppimismalli (ennustava resilienssi-indikaattori)
- Integraatio muihin virallisiin järjestelmiin

---

## Liitteet

**A. API-dokumentaatio**
- Fingrid: https://data.fingrid.fi/open-data-forms/api/
- FMI: https://en.ilmatieteenlaitos.fi/open-data

**B. Lähdekoodirepositorio**
- (Linkki GitHubiin tai sisäiseen repoon)

**C. Audit-login formaatti**
```json
{
  "timestamp": "2026-01-31T12:34:56Z",
  "locks": {
    "Reserve": "WEAK",
    "Time": "CRITICAL"
  },
  "signals": {
    "frequency": 50.02,
    "consumption": 8500,
    "production": 8450,
    "reserves": 420,
    "time_lock_p": 0.72,
    "temp_med": -21.5,
    "wind_med": 1.5
  },
  "resilience_index": 0.67,
  "case_id": "CASE-1738245932"
}
```
