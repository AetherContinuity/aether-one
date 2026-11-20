# Aether One™ — Pi 2 Trust Server

**Minimaalinen TrustCore attestation server Raspberry Pi 2:lle.**

Tämä paketti sisältää **vain** TrustCore serverin — ei sensoreita, ei dashboardeja, ei edge-laskentaa.

---

## Laitteisto

- **Raspberry Pi 2 Model B** (BCM2836, 1 GB RAM)
- MicroSD-kortti (8 GB riittää)
- Verkkoliitäntä (Ethernet tai WiFi)

---

## Asennus

### 1. Kopioi paketti Pi 2:lle

```bash
# Tietokoneelta (jos Pi 2:ssa SSH):
scp -r pi2_trust_server/ pi@<pi2_ip>:~/

# Tai USB-tikulla / microSD:llä
```

### 2. Kirjaudu Pi 2:lle ja asenna

```bash
cd ~/pi2_trust_server
chmod +x install.sh start.sh
./install.sh
```

### 3. (Valinnainen) Aseta staattinen IP

**Suositus:** Anna Pi 2:lle staattinen IP, esim. `192.168.1.50`

```bash
sudo nmcli con mod "Wired connection 1" ipv4.addresses 192.168.1.50/24
sudo nmcli con mod "Wired connection 1" ipv4.gateway 192.168.1.1
sudo nmcli con mod "Wired connection 1" ipv4.dns "8.8.8.8"
sudo nmcli con mod "Wired connection 1" ipv4.method manual
sudo nmcli con up "Wired connection 1"
```

Tai WiFi:llä: korvaa `"Wired connection 1"` → `"preconfigured"` (tai oman WiFi-yhteytesi nimi).

---

## Käynnistys

```bash
cd ~/pi2_trust_server
./start.sh
```

Server käynnistyy portissa **5000**.

Näet Pi 2:n IP:n skriptin tulostuksessa:
```
📡 Server IP: 192.168.1.50
🔌 Server URL: http://192.168.1.50:5000
```

---

## Testaus

Toiselta koneelta samassa verkossa:

```bash
# Hae nonce
curl http://192.168.1.50:5000/nonce

# Rekisteröidyt laitteet (Pi 2:lla)
python -m core.trustcore.admin list
```

---

## Laitteen rekisteröinti (käsin)

Todentaja ei rekisteröi laitetta ensimmäisellä näkemällä. Omistaja vie
rekisteröintitiedot laitteelta Pi 2:lle itse (USB, scp omalla tunnuksella):

```bash
# Laitteella (Pi 5):
python -c "from core.trustcore.client import TrustCoreClient, TrustCoreConfig as C; \
import json; print(json.dumps(TrustCoreClient(C(server_url='-')).export_enrollment(platform='rpi5', tpm_kind='hardware')))" > laite.json

# Pi 2:lla:
python -m core.trustcore.admin enroll laite.json
```

`admin enroll` lukee AK:n attribuutit TPM2B_PUBLIC-rakenteesta ja hylkää
avaimen, joka ei ole `restricted|sign|fixedtpm`. Swtpm-laite rekisteröidään
`tpm_kind='swtpm'`, jolloin väite A on enintään `PARTIAL`.

---

## Mitä Pi 2 tekee?

1. **Vastaa attestation-pyyntöihin** Pi 5:ltä
2. **Generoi nonce**-haasteet
3. **Tarkistaa TPM-quoten** (`tpm2_checkquote`: AK-allekirjoitus, nonce, PCR-digest)
4. **Varmentaa ML-DSA-65-allekirjoituksen** rekisteröityä avainta vasten
5. **Vastaa väitekohtaisesti** (A, B, P, Q; `docs/ATTESTATION-LEVELS.md`), ei yhteistä PASS/FAIL-tilaa
6. **Kirjaa lokiin** `trustcore_server.log`

**Pi 2 ei:**
- ❌ Lue sensoreita
- ❌ Laske KRI/LR-arvoja
- ❌ Tarjoa web-UI:ta

---

## Konfigurointi

Ympäristömuuttujat:

```bash
TRUSTCORE_PORT=5000                  # portti
TRUSTCORE_DATA_DIR=.trustcore_server # devices.json
TRUSTCORE_NONCE_TTL=120              # noncen elinikä sekunteina
```

---

## Sammutus

```bash
# Pysäytä server
CTRL+C

# Tai tappo taustalta
pkill -f "core.trustcore.server"
```

---

## Vianetsintä

**Ongelma:** "Address already in use (port 5000)"

```bash
# Tarkista mikä käyttää porttia
sudo lsof -i :5000

# Tappo vanha prosessi
pkill -f "core.trustcore.server"
```

**Ongelma:** "ModuleNotFoundError: No module named 'core'"

→ Varmista että olet `pi2_trust_server/` hakemistossa ja `.venv` on aktivoitu.

**Ongelma:** Pi 5 ei saa yhteyttä

```bash
# Tarkista että Pi 2 vastaa
ping <pi2_ip>

# Tarkista firewall
sudo ufw status
# Jos aktiivinen, salli portti 5000:
sudo ufw allow 5000/tcp
```

---

## Seuraava askel

Kun Pi 2 server pyörii:
1. Asenna **Pi 5 Edge Node** -paketti
2. Konfiguroi Pi 5 käyttämään Pi 2:n IP:tä
3. Katso miten attestation toimii kahden laitteen välillä

---

**Pi 2 on nyt turvallinen trust-ankkuri — kevyt, dedioitu ja erillinen edge-nodesta.** 🔐
