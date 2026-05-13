# Aether One™ Dual-Pi — QUICK START

**Lataa tämä paketti ja käynnistä molemmat Pi:t 15 minuutissa.**

---

## Paketit

Sinulla on nyt kolme zip-tiedostoa:

1. **aether_one_dual_pi_complete.zip** — Kaikki (suositus)
2. **pi2_trust_server_only.zip** — Vain Pi 2
3. **pi5_edge_node_only.zip** — Vain Pi 5

---

## Vaihe 1: Pura paketit

```bash
unzip aether_one_dual_pi_complete.zip
cd aether_one_dual_pi_complete/
```

Sisältää:
```
pi2_trust_server/       ← Kopioi Pi 2:lle
pi5_edge_node/          ← Kopioi Pi 5:lle
README.md               ← Täysi dokumentaatio
NETWORK_SETUP.md        ← Verkko-ohjeet
```

---

## Vaihe 2: Siirrä Pi:lle

### Vaihtoehto A: SSH (helpoin)

```bash
# Pi 2
scp -r pi2_trust_server/ pi@<pi2_ip>:~/

# Pi 5
scp -r pi5_edge_node/ pi@<pi5_ip>:~/
```

### Vaihtoehto B: USB-tikku

1. Kopioi `pi2_trust_server/` USB-tikulle
2. Pi 2:lla: `cp -r /media/usb/pi2_trust_server ~/`
3. Toista Pi 5:lle

---

## Vaihe 3: Asenna ja käynnistä

### Pi 2 (Trust Server):

```bash
ssh pi@<pi2_ip>
cd ~/pi2_trust_server
./install.sh
./start.sh
```

Näet:
```
🔐 Aether One — TrustCore Trust Server
======================================
📡 Server IP: 192.168.1.50
🔌 Server URL: http://192.168.1.50:5000
```

**Jätä terminaali pyörimään!**

### Pi 5 (Edge Node):

Uusi terminaali:
```bash
ssh pi@<pi5_ip>
cd ~/pi5_edge_node

# Konfiguroi Pi 2 IP (jos eri kuin 192.168.1.50)
nano core/config.py
# → Vaihda AETHER_ATTESTATION_SERVER_URL

./install.sh
./start.sh
```

Näet:
```
🔬 Aether One — Pi5 Edge Node
==============================
📡 Edge Node IP: 192.168.1.51
🔌 API URL: http://192.168.1.51:8080
```

---

## Vaihe 4: Testaa

### Terminaalista:

```bash
# Pi 5:ltä → Pi 2:lle
curl http://192.168.1.50:5000/nonce
# → {"nonce": "abc123..."}

# Pi 5 API
curl http://localhost:8080/attestation
# → {"status": "PASS", ...}

# Sensorit
curl http://localhost:8080/sensor/mq9
# → {"source": "mock", "normalized": 0.6234, ...}
```

### Selaimessa (tietokoneelta tai Pi 5:ltä):

**Web UI:**
```
http://<pi5_ip>:8080/ui/
```

**Swagger API:**
```
http://<pi5_ip>:8080/docs
```

---

## Ongelmanratkaisu

### "Connection refused" (Pi 5 → Pi 2)

1. Tarkista Pi 2 pyörii: `ps aux | grep trustcore`
2. Tarkista verkko: `ping 192.168.1.50`
3. Tarkista firewall: `sudo ufw status`

### "Attestation: FAIL"

1. Odota 10-30 sekuntia (attestation-intervalli)
2. Tarkista Pi 2 lokit: `tail -f ~/pi2_trust_server/trustcore_server.log`
3. Force retry: `curl http://localhost:8080/attestation`

### "Sensors not initialized"

→ Restart: `./start.sh`

### Mock-data näkyy vaikka sensori on kiinni

→ Asenna kirjastot:
```bash
# MQ-9 (Explorer HAT):
pip install explorerhat

# AetherCam (kamera):
# Ei tarvitse mitään, pelkkä IP riittää
```

---

## Seuraavat askeleet

**Kun molemmat Pi:t pyörivät:**

1. **Avaa dashboard:** `http://<pi5_ip>:8080/ui/`
2. **Lue täysi dokumentaatio:** `README.md`
3. **Konfiguroi verkko:** `NETWORK_SETUP.md` (staattinen IP, mDNS)
4. **Lisää oikeat sensorit:**
   - MQ-9: Explorer HAT tai ADS1115
   - S21: IP Webcam -sovellus

---

## Tarvitsetko apua?

- 📄 **README.md** — Täysi tekninen dokumentaatio
- 📄 **NETWORK_SETUP.md** — WiFi + IP -konfiguraatio
- 📄 **pi2_trust_server/README.md** — Pi 2 -spesifit ohjeet
- 📄 **pi5_edge_node/README.md** — Pi 5 -spesifit ohjeet

---

**Onnea! 15 minuutissa sinulla on toimiva dual-Pi trust + sensor -järjestelmä.** 🚀
