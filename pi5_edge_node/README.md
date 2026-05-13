# Aether One™ — Pi5 Edge Node (Unified)

**Täysiverinen edge-node joka yhdistää:**
- TrustCore v1.0 attestation (PQC + TPM)
- Fyysiset sensorit (MQ-9 kaasu + AetherCam IP-kamera)
- TrustCore v1.0 deterministic C-kernel (KRI + LR-D)
- Live dashboard + web UI

---

## Laitteisto

- **Raspberry Pi 5** (suositus: 4-8 GB RAM)
- **MicroSD-kortti** (32 GB suositus)
- **Verkko** (WiFi tai Ethernet)

### Valinnaiset sensorit:

**MQ-9 kaasusensori:**
- Explorer HAT Pro (helpoin, plug-and-play)
- TAI ADS1115 I2C ADC breakout

**AetherCam:**
- Samsung S21 (tai mikä tahansa Android-puhelin)
- IP Webcam -sovellus (ilmainen)

**HUOM:** Kaikki toimii mock-datalla ilman fyysisiä sensoreita!

---

## Asennus

### 1. Kopioi paketti Pi 5:lle

```bash
# SSH:n kautta:
scp -r pi5_edge_node/ pi@<pi5_ip>:~/

# Tai USB-tikku / microSD
```

### 2. Asenna

```bash
cd ~/pi5_edge_node
chmod +x install.sh start.sh
./install.sh
```

---

## Konfigurointi

### A) Pi 2 Trust Server (jos käytössä)

Muokkaa `core/config.py`:

```python
AETHER_ATTESTATION_ENABLED = True
AETHER_ATTESTATION_SERVER_URL = "http://192.168.1.50:5000"  # Pi 2 IP
```

### B) AetherCam IP-osoite (S21)

Muokkaa `sensor_reader/aethercam_reader.py`:

```python
DEFAULT_STREAM_URL = "http://192.168.1.105:8080/video"  # S21 IP
```

**S21 setup:**
1. Asenna **IP Webcam** (Google Play)
2. Käynnistä → **Start server**
3. Näet IP:n ruudulla (esim. `192.168.1.105:8080`)
4. Testaa: avaa selaimessa `http://192.168.1.105:8080/video`

### C) MQ-9 sensori (jos käytössä)

**Explorer HAT Pro:**
```bash
pip install explorerhat
```

**ADS1115:**
```bash
pip install adafruit-circuitpython-ads1x15
```

Ei tarvitse muokata koodia — automaattinen tunnistus.

---

## Käynnistys

```bash
cd ~/pi5_edge_node
./start.sh
```

Pi 5 käynnistyy portissa **8080**.

---

## Käyttöliittymät

### 1. Web UI (runtime-clean alkuperäinen)

```
http://<pi5_ip>:8080/ui/
```

Näyttää:
- Live sensor state (mock tai oikea)
- LR status (OK / WATCH / ALERT)
- KRI + LR-D arvot
- Attestation status

### 2. Drift Monitor (v7.1 standalone dashboard)

**Avaa Pi 5:n selaimessa:**
```bash
chromium-browser ~/pi5_edge_node/dashboards/global_drift_monitor.html
```

TAI **toiselta koneelta** samassa verkossa:
1. Jaa kansio: `cd ~/pi5_edge_node && python3 -m http.server 8888`
2. Avaa: `http://<pi5_ip>:8888/dashboards/global_drift_monitor.html`

Dashboard näyttää:
- MQ-9 + AetherCam reaaliaikadatan
- TrustCore KRI-arvon
- LR-tilan (OK/WATCH/ALERT)
- Attestation-statuksen
- Mock vs real sensor -badgen

### 3. API Swagger UI

```
http://<pi5_ip>:8080/docs
```

Interaktiivinen API-dokumentaatio.

---

## Testaus

### Mock-tilassa (ei sensoreita):

```bash
curl http://localhost:8080/sensor/mq9
# → {"source": "mock", "normalized": 0.6234, ...}

curl http://localhost:8080/sensor/aethercam
# → {"source": "mock", "normalized": 0.4512, ...}

curl http://localhost:8080/node_status_realtime
# → {"R": 0.75, "S": 0.62, "E": 0.45, "kri": 0.6123, ...}
```

### Oikeilla sensoreilla:

```bash
curl http://localhost:8080/sensor/mq9
# → {"source": "explorerhat", "normalized": 0.1234, ...}

curl http://localhost:8080/sensor/aethercam
# → {"source": "aethercam", "normalized": 0.2345, ...}
```

### Attestation (jos Pi 2 käytössä):

```bash
curl http://localhost:8080/attestation
# → {"status": "PASS", "device_id": "abc123...", ...}
```

---

## Kahden Pi:n setup (Pi 2 + Pi 5)

### Pi 2 (Trust Server):
```bash
cd ~/pi2_trust_server
./start.sh
# → Server pyörii portissa 5000
```

### Pi 5 (Edge Node):
```bash
# Varmista config.py:ssä:
# AETHER_ATTESTATION_SERVER_URL = "http://192.168.1.50:5000"

cd ~/pi5_edge_node
./start.sh
```

**Tarkista yhteys:**
```bash
# Pi 5:ltä
curl http://192.168.1.50:5000/nonce
# → {"nonce": "abc123..."}

# Pi 5 API:sta
curl http://localhost:8080/attestation
# → {"status": "PASS", ...}
```

---

## Arkkitehtuuri

```
┌─────────────────────────────────────┐
│  Pi 5 (Edge Node)                   │
│  ┌───────────────────────────────┐  │
│  │ Sensors                       │  │
│  │  - MQ-9 (kaasu)               │  │
│  │  - AetherCam (kamera)         │  │
│  └──────────┬────────────────────┘  │
│             ▼                        │
│  ┌───────────────────────────────┐  │
│  │ sensor_reader/               │  │
│  │  - BaseSensor interface      │  │
│  │  - Auto fallback to mock     │  │
│  └──────────┬────────────────────┘  │
│             ▼                        │
│  ┌───────────────────────────────┐  │
│  │ TrustCore v1.0 C-kernel      │  │
│  │  - tc_calculate_kri()        │  │
│  │  - tc_calculate_dissonance() │  │
│  └──────────┬────────────────────┘  │
│             ▼                        │
│  ┌───────────────────────────────┐  │
│  │ Aether Relay API             │  │
│  │  - /sensor/mq9               │  │
│  │  - /sensor/aethercam         │  │
│  │  - /node_status_realtime     │  │
│  │  - /kri, /lr, /attestation   │  │
│  └──────────┬────────────────────┘  │
│             │                        │
│             ├─► Web UI (:8080/ui/)  │
│             └─► Drift Monitor       │
└─────────────┼────────────────────────┘
              │
              │ WiFi (Attestation)
              ▼
┌─────────────────────────────────────┐
│  Pi 2 (Trust Server)                │
│  ┌───────────────────────────────┐  │
│  │ TrustCore Server (:5000)     │  │
│  │  - Nonce generation          │  │
│  │  - PQC signature verify      │  │
│  │  - Device enrollment         │  │
│  │  - Audit log                 │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

---

## Vianetsintä

### "Sensors not initialized"
→ Restart relay: `./start.sh`

### "AetherCam stream unavailable"
→ Tarkista S21 IP Webcam pyörii ja IP-osoite on oikein.

### "MQ9Reader: using MOCK data"
→ Explorer HAT / ADS1115 ei löydy → asennus: `pip install explorerhat`

### "Attestation: UNKNOWN"
→ Pi 2 server ei vastaa:
```bash
ping 192.168.1.50
curl http://192.168.1.50:5000/nonce
```

### "TrustCore init failed"
→ Normaali jos Pi 2 ei käytössä. Attestation deaktivoitu.

---

## Seuraavat askeleet

1. **Lisää sensoreita:**
   - VOC (SGP30)
   - Geiger (RadiationWatch)
   - LiDAR (TFMini)

2. **Paranna dashboardia:**
   - WebSocket live-stream
   - Historian visualisointi
   - Hälytysasetukset

3. **Tuotantokäyttö:**
   - Systemd service
   - Automaattinen uudelleenkäynnistys
   - Log rotation

4. **MCP server integraatio:**
   - Claude API -yhteensopivuus
   - Narrative engine liittäminen

---

**Pi 5 on nyt täysiverinen edge-node — fyysisiä sensoreita, trust-infraa ja live-dashboardia.** 🔬
