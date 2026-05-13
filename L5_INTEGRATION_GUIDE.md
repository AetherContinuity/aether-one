# ⚡ KaraokeKoppi L5-CORE Integraatio

## 📦 MITÄ SAAT:

1. **FMI Time-Lock** → Sää rakenteellisena riskinä (ei vain lämpötilana)
2. **Case Manager** → Älykäs eskalaatio (ei turhaa hälytystä)

---

## 🔧 ASENNUSOHJEET (VPS)

### 1. Pura tiedostot

```bash
cd ~/karaokekoppi

# Pura L5_CORE
unzip AO-DECISION-L5_CORE.zip

# Tarkista:
ls hub/app/case_manager.py   # Pitäisi löytyä
ls ssa/weather_fmi.py         # Pitäisi löytyä
```

---

### 2. Muokkaa SSA (lisää FMI Time-Lock)

Avaa: `ssa/main.py` (tai `ssa/adapter.py` riippuen arkkitehtuurista)

**LISÄÄ ALKUUN:**
```python
from weather_fmi import calculate_time_lock
```

**ETSI KOHTA JOSSA SNAPSHOT LUODAAN** (esim. `snapshot = {...}`)

**LISÄÄ ENNEN TALLENNUSTA:**
```python
# Hae FMI Time-Lock
time_lock = calculate_time_lock()

# Lisää snapshotiin
snapshot["locks"]["Time"] = time_lock["status"]
snapshot["signals"]["time_lock_p"] = time_lock["time_p"]
snapshot["signals"]["temp_med"] = time_lock["metrics"]["t_med"]
snapshot["signals"]["wind_med"] = time_lock["metrics"]["w_med"]

print(f"[FMI] Time Lock: {time_lock['status']} (p={time_lock['time_p']}, T={time_lock['metrics']['t_med']}°C)")
```

---

### 3. Muokkaa HUB (lisää Case Manager)

Avaa: `hub/main.py` (tai päälooppi-tiedosto)

**LISÄÄ ALKUUN:**
```python
from app.case_manager import CaseManager

# Luo Case Manager (kerran)
case_manager = CaseManager(debounce_seconds=600)  # Max 1 case / 10min
```

**ETSI KOHTA JOSSA RESILIENCE INDEX ON LASKETTU**

**LISÄÄ PERÄÄN:**
```python
# Arvioi tarvitaanko uusi Case
triggered, case_id, reason = case_manager.evaluate({
    "resilience_index": resilience_index,
    "locks": snapshot.get("locks", {})
})

if triggered:
    print(f"[CASE] 🚨 Uusi case: {case_id} ({reason})")
    
    # Lähetä hälytys
    send_email(
        subject=f"KRIISIHÄLYTYS: {case_id}",
        body=f"Resilienssi: {resilience_index:.2f}\nSyy: {reason}"
    )
else:
    print(f"[CASE] ✅ Ei eskalaatiota (index={resilience_index:.2f})")
```

---

### 4. Päivitä .env

```bash
nano .env
```

**LISÄÄ:**
```
FMI_PLACES=Helsinki,Kuopio,Oulu,Rovaniemi
```

*(Ei API-avainta tarvita FMI:lle)*

---

### 5. Käynnistä uudelleen

```bash
docker-compose down
docker-compose up -d --build
docker-compose logs -f orchestrator
```

---

## ✅ TOIMIVA JÄRJESTELMÄ NÄYTTÄÄ TÄLTÄ:

### SSA Snapshot:
```json
{
  "timestamp": "2026-01-31T12:34:56Z",
  "locks": {
    "Reserve": "WEAK",
    "Time": "CRITICAL"
  },
  "signals": {
    "frequency": 50.02,
    "time_lock_p": 0.72,
    "temp_med": -21.4,
    "wind_med": 1.8
  }
}
```

### Hub Logs:
```
[FMI] Time Lock: CRITICAL (p=0.72, T=-21.4°C)
[CASE] 🚨 Uusi case: CASE-1738245932 (LOCK_CRITICAL)
[EMAIL] Lähetetään kriisihälytys...
```

### Dashboard:
- **Time Lock**: 🔴 CRITICAL
- **Resilience Index**: 0.67 (lasku 0.08)
- **Case**: CASE-1738245932 aktiivinen

---

## 🧠 MITÄ MUUTTUI:

### ENNEN:
```
"Taajuus 50 Hz, kaikki hyvin"
```

### NYT:
```
"Koko maa -22°C, tuuli 2 m/s, reservit ohuet
→ Resilienssi murenee vaikka taajuus vielä normaali"
```

**Järjestelmä siirtyi reaktiivisesta → ennakoivaan.**

---

## 🔍 TESTAUS:

```bash
# Testaa FMI erikseen:
python3 -c "from ssa.weather_fmi import calculate_time_lock; print(calculate_time_lock())"

# Odotettu tulos:
# {'status': 'WEAK', 'time_p': 0.42, 'metrics': {'t_med': -8.5, 'w_med': 4.2}}

# Testaa Case Manager erikseen:
python3 -c "
from hub.app.case_manager import CaseManager
cm = CaseManager()
print(cm.evaluate({'resilience_index': 0.75, 'locks': {'Time': 'CRITICAL'}}))
"

# Odotettu tulos:
# (True, 'CASE-1738...', 'LOCK_CRITICAL')
```

---

## 🚨 KRIISISKENAARIO (simuloitu):

### T=0min: Normaali tila
```
Index: 0.92, Time: OK, Reserve: OK
→ Ei case
```

### T=5min: Sää heikkenee
```
Index: 0.92, Time: WEAK, Reserve: OK
→ Ei case (ei CRITICAL)
```

### T=10min: Kriisi
```
Index: 0.84, Time: CRITICAL, Reserve: WEAK
→ CASE-1738... käynnistyy (INDEX_DROP_0.08+LOCK_CRITICAL)
→ Sähköposti lähetetään
```

### T=15min: Jatkuu
```
Index: 0.82, Time: CRITICAL, Reserve: WEAK
→ Ei uutta casea (debounce, max 1/10min)
```

### T=25min: Pahenee
```
Index: 0.74, Time: CRITICAL, Reserve: CRITICAL
→ CASE-1738... (UUSI case, debounce ohi)
```

---

## 🎯 SEURAAVA TASO (suositus):

**Decision Matrix** → Toimenpiteiden vaikutuslukot

Dashboard näyttäisi:
```
Toimenpide        Reserve  Time  Governance  Indeksi
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Kysyntäjousto        ↑       →       ↓        +0.08
Kiertävät katkot    ↑↑      ↑      ↓↓        +0.14
Viestintä            →       →       ↑        +0.02
```

**Tämä tekisi valvomosta päätöksenteon työkalun, ei vain hälytysnäytön.**

---

## ✅ VALMIS

Node 001 on nyt **ennakoiva**, ei vain reaktiivinen.

Se näkee kriisin ENNEN kuin taajuus romahtaa.
