# DECISION MATRIX - DEMO & INTEGRAATIO

## 📊 DEMO: Käytä Decision Matrixia

```python
from decision_matrix_full import ACTIONS
from recommendation_engine import RecommendationEngine

# Kriisitilanne: Reservit kriittisellä tasolla, sää heikko
crisis_snapshot = {
    "timestamp": "2026-01-31T12:00:00Z",
    "locks": {
        "Reserve": "CRITICAL",  # Reservit loppumassa
        "Time": "WEAK",         # Kylmä + tyyntä
        "Governance": "OK"
    },
    "signals": {
        "frequency": 49.92,
        "reserves": 350,  # Normaali ~800 MW
        "temp_med": -18.5,
        "wind_med": 3.2
    },
    "resilience_index": 0.67  # KRIITTINEN
}

# Luo suositusmoottori
engine = RecommendationEngine(ACTIONS)

# Hae suositukset (3 parasta vaihtoehtoa)
recommendations = engine.recommend(
    crisis_snapshot,
    max_recommendations=3,
    risk_tolerance="medium"  # "low", "medium", tai "high"
)

# Tulosta suositukset
print("=== TOIMENPIDESUOSITUKSET ===\n")
for i, rec in enumerate(recommendations, 1):
    print(f"SUOSITUS {i} (Prioriteetti: {rec.priority})")
    print(f"Toimenpiteet: {', '.join(rec.action_names)}")
    print(f"Vaikutus indeksiin: {rec.expected_index_improvement:+.2f} ({crisis_snapshot['resilience_index']:.2f} → {crisis_snapshot['resilience_index'] + rec.expected_index_improvement:.2f})")
    print(f"Käyttöönottoaika: {rec.time_to_effect_minutes} min")
    print(f"Kustannus: {rec.total_cost_eur:,.0f} EUR")
    print(f"Henkilöstö: {rec.total_personnel} hlö")
    print(f"Riski: {rec.risk_level} (poliittinen: {rec.risk_breakdown['political']}, tekninen: {rec.risk_breakdown['technical']})")
    print(f"Perustelu: {rec.rationale}")
    print(f"\nLukkojen muutokset:")
    for lock, change in rec.expected_lock_improvements.items():
        if abs(change) > 0.01:
            print(f"  {lock}: {change:+.2f}")
    print("\n" + "-"*60 + "\n")
```

## 📋 ODOTETTU TULOS:

```
=== TOIMENPIDESUOSITUKSET ===

SUOSITUS 1 (Prioriteetti: 1)
Toimenpiteet: Kysyntäjousto - Teollisuus, Varavoiman käynnistys
Vaikutus indeksiin: +0.18 (0.67 → 0.85)
Käyttöönottoaika: 60 min
Kustannus: 250,000 EUR
Henkilöstö: 15 hlö
Riski: medium (poliittinen: medium, tekninen: low)
Perustelu: Parantaa Reserve-lukon tilaa merkittävästi (+0.55). Nostaa resilienssindeksiä +0.18. Matala poliittinen riski.

Lukkojen muutokset:
  Reserve: +0.55
  Time: +0.05
  Governance: -0.18

------------------------------------------------------------

SUOSITUS 2 (Prioriteetti: 2)
Toimenpiteet: Varavoiman käynnistys
Vaikutus indeksiin: +0.12 (0.67 → 0.79)
Käyttöönottoaika: 60 min
Kustannus: 200,000 EUR
Henkilöstö: 10 hlö
Riski: medium (poliittinen: medium, tekninen: low)
Perustelu: Parantaa Reserve-lukon tilaa merkittävästi (+0.30). Nostaa resilienssindeksiä +0.12. Nopea käyttöönotto.

Lukkojen muutokset:
  Reserve: +0.30
  Time: +0.05
  Governance: -0.08

------------------------------------------------------------

SUOSITUS 3 (Prioriteetti: 3)
Toimenpiteet: Kysyntäjousto - Kotitaloudet, Viestintä - Hätätilanne
Vaikutus indeksiin: +0.07 (0.67 → 0.74)
Käyttöönottoaika: 30 min
Kustannus: 15,000 EUR
Henkilöstö: 5 hlö
Riski: low (poliittinen: low, tekninen: low)
Perustelu: Nopea käyttöönotto. Matala poliittinen riski.

Lukkojen muutokset:
  Reserve: +0.20
  Governance: +0.03

------------------------------------------------------------
```

---

## 🔧 INTEGRAATIO KARAOKEKOPPIIN

### 1. Kopioi tiedostot VPS:lle

```bash
cd ~/karaokekoppi

# Luo hub/decision hakemisto
mkdir -p hub/decision

# Kopioi moduulit
cp decision_matrix_full.py hub/decision/decision_matrix.py
cp action_simulator.py hub/decision/
cp recommendation_engine.py hub/decision/
```

### 2. Lisää Hub:n päälooppiin

Muokkaa `hub/main.py`:

```python
from decision.recommendation_engine import RecommendationEngine
from decision.decision_matrix import ACTIONS

# Luo suositusmoottori (kerran, ohjelman alussa)
recommendation_engine = RecommendationEngine(ACTIONS)

# ... (pääloop)

# Kun Case Manager käynnistää casen:
if case_triggered:
    # Hae suositukset
    recommendations = recommendation_engine.recommend(
        current_snapshot,
        max_recommendations=3,
        risk_tolerance="medium"
    )
    
    # Lähetä sähköpostiin
    email_body = format_recommendations_for_email(recommendations)
    send_email(
        subject=f"KRIISIHÄLYTYS: {case_id} - TOIMENPIDESUOSITUKSET",
        body=email_body
    )
    
    # Tallenna audit-logiin
    audit_log_recommendations(case_id, recommendations)
```

### 3. Dashboard-integraatio (valinnainen)

Jos haluat näyttää suositukset Dashboardissa:

```python
# hub/api.py (tai vastaava)

@app.route("/api/recommendations")
def get_recommendations():
    current_snapshot = load_latest_snapshot()
    
    recommendations = recommendation_engine.recommend(
        current_snapshot,
        max_recommendations=5,
        risk_tolerance=request.args.get("risk_tolerance", "medium")
    )
    
    return jsonify([
        {
            "priority": rec.priority,
            "actions": rec.action_names,
            "index_improvement": rec.expected_index_improvement,
            "time_minutes": rec.time_to_effect_minutes,
            "cost_eur": rec.total_cost_eur,
            "risk": rec.risk_level,
            "rationale": rec.rationale
        }
        for rec in recommendations
    ])
```

---

## 🎯 KÄYTTÖTAPAUKSET

### 1. AUTOMAATTINEN (Kriisihälytyksen yhteydessä)

```
CASE-1738245932 käynnistyy (Index drop 0.08)
  ↓
Recommendation Engine aktivoituu automaattisesti
  ↓
3 parasta suositusta liitetään sähköpostiin
  ↓
Päättäjät näkevät MITÄ TEHDÄ, ei vain "mitä on väärin"
```

### 2. MANUAALINEN (Dashboard)

```
Päättäjä kirjautuu Dashboardiin
  ↓
Näkee "Mitä jos...?" -painikkeen
  ↓
Valitsee risk tolerance (low/medium/high)
  ↓
Saa 3-5 suositusta heti
```

### 3. SKENAARIOANALYYSI

```python
# "Mitä jos sää heikkenee entisestään?"
future_snapshot = current_snapshot.copy()
future_snapshot["locks"]["Time"] = "CRITICAL"
future_snapshot["signals"]["temp_med"] = -25.0

future_recommendations = recommendation_engine.recommend(
    future_snapshot,
    risk_tolerance="high"  # Sallii radikaalimmat toimenpiteet
)
```

---

## ✅ TARKISTUSLISTA

Kun Decision Matrix on integroitu:

- [ ] Tiedostot kopioi VPS:lle (`hub/decision/`)
- [ ] Hub kutsuu `recommendation_engine.recommend()` kun case käynnistyy
- [ ] Suositukset liitetään kriisihälytykseen (sähköposti)
- [ ] (Valinnainen) Dashboard näyttää suositukset
- [ ] (Valinnainen) API-endpoint `/api/recommendations`
- [ ] Testaa: Simuloi kriisi ja tarkista että suositukset tulevat

---

## 🎓 MITÄ TÄMÄ MUUTTAA:

**ENNEN:**
```
Sähköposti: "KRIISI! Resilienssi 0.67"
Päättäjä: "Okei... no mitä teen?"
```

**JÄLKEEN:**
```
Sähköposti:
  KRIISI! Resilienssi 0.67
  
  SUOSITELLUT TOIMENPITEET:
  
  1. Kysyntäjousto + Varavoima
     → Index 0.67 → 0.85 (60 min, 250k EUR)
  
  2. Varavoima
     → Index 0.67 → 0.79 (60 min, 200k EUR)
  
  3. Kysyntäjousto + Viestintä
     → Index 0.67 → 0.74 (30 min, 15k EUR)

Päättäjä: "Selvä, vaihtoehto 1 käyntiin!"
```

**Valvomo muuttuu päätöksenteon työkaluksi, ei vain hälytysnäytöksi.**
