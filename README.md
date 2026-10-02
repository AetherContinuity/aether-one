# Aether One™

Tutkimusprototyyppi: kahden Raspberry Pi:n luottamusankkuri- ja reunalaskenta-asetelma sekä
synteesikelpoiset RTL-ytimet NIST:n kvanttiturvallisille algoritmeille ML-KEM (FIPS 203) ja
ML-DSA (FIPS 204).

Tämä ei ole tuote eikä valmis käyttöön. Tavoite on arkkitehtuurin ja ACVP-ankkuroidun
oikeellisuuden tutkiminen, ei suorituskyky (ks. `PROJECT_STATUS_AND_DIRECTION.md`).
Avoimet kohdat ovat tiedostossa [`KORJAUSLISTA.md`](KORJAUSLISTA.md).

**Tila päivitetty:** 2026-10-02. Viimeisin muutos SystemVerilog-tiedostoihin: 2026-07-22.

## Tausta

Aether One on yksi toteutus DCEIN-arkkitehtuurista (Duration-Capable Edge Intelligence Node):
päätöksen tekevä yksikkö (ECU) ja sen validoiva, fyysisesti erillinen luottamusankkuri (TAU).

- [WP-006 — Continuity Computing](https://aethercontinuity.org/papers/wp-006-continuity-computing.html)
- [WP-007 — Situational Awareness Persistence](https://aethercontinuity.org/papers/wp-007-situational-awareness-persistence.html)
- [TN-002 — DCEIN Architecture](https://aethercontinuity.org/supplements/tn-002-dcein.html)

## Tila osittain

"CI" tarkoittaa, että testi ajetaan jokaisella pushilla (`.github/workflows/verify.yml`).
"Kerta-ajo" tarkoittaa, että tulos on kirjattu statusdokumenttiin, mutta testi ei ole CI:ssä.
"Käsin käynnistettävä" tarkoittaa workflow'ta, joka ei aja itsestään.

### Pi-prototyyppi (`pi2_trust_server/`, `pi5_edge_node/`)

| Osa | Tila | Todennus |
|---|---|---|
| Trust Server: nonce, laitteen rekisteröinti, attestaatio, ML-DSA-65-allekirjoitus liboqs:n kautta | Toteutettu (Python, FastAPI) | CI: rekisteröintihyökkäystesti, TPM+PQC-päästä-päähän-testi ohjelmisto-TPM:llä (swtpm), asennusskriptin testi |
| Edge Node: KRI/LR-laskenta, web-käyttöliittymä, drift-näkymät | Toteutettu (Python) | Ei automaattista testiä |
| Sensorit: MQ-9 (ADC), AetherCam, mock-varavaihtoehto | Ajurit olemassa | Ei automaattista testiä |
| C-ydin (`libtrustcore.so`) | Ei repossa | — |
| Ajo fyysisillä Pi-laitteilla | Ei mittauksia repossa | — |

`install.sh` rakentaa liboqs:n ja keskeyttää asennuksen, jos ML-DSA-65-itsetesti ei mene läpi
(`install_liboqs.sh`; testattu x86-Linuxilla ja CI:ssä, ei Raspberry Pi:llä). Latenssi- ja
kuormalukuja ei ole mitattu.

### ML-KEM-512 RTL (`hardware/pqc-rtl/rtl/`, `fpga/`)

| Osa | Tila | Todennus |
|---|---|---|
| FIPS 203:n algoritmit 3–21: primitiivit, K-PKE, ML-KEM `_internal` (KeyGen, Encaps, Decaps) | Synteesikelpoinen SystemVerilog, K=2 | CI: Icarus-simulaatiot, K-PKE-kierros, Decaps TB A/B, KeyGen 10 kertaa samassa simulaatiossa; `FIPS203_COVERAGE.md` |
| Keccak-p[1600,24], SHA3-256/512, SHAKE128/256 | Synteesikelpoinen | Testipenkit NIST-ankkuroitua golden-mallia vasten |
| Golden-malli (Python) | — | CI: 1000 satunnaista (d, z, m) -syötettä, jäädytettyjen vektorien tarkistus |
| NIST ACVP: KeyGen 1 vektori, Encaps 3, Decaps 5 (sis. hylkäystapaukset) | PASS | CI: `run_acvp_mlkem.sh`, mukana kolme negatiivikontrollia; `M3_MLKEM_ACVP_STATUS.md` |
| 4-pankkinen konfliktiton NTT-muisti | SAT-todistettu | `BANK_MAPPING_PROOF.md` |
| NTT-ydin ECP5:llä: synteesi ja P&R, DP16KD = 4, Fmax 30,40 MHz (ECP5-25k) | Tehty | `fpga/timing_reports/` |
| Koko ML-KEM-ytimen (orkestrointi) synteesi ja P&R | Ei valmistunut (resurssiraja) | `fpga/tau/M4_DECAPS_ORCH_001_STATUS.md` |
| Decaps-ajoitus: syklitasolla vakioaikainen salaisen datan suhteen | Mitattu saman avaimen vertailulla | Kerta-ajo, `M3_MLKEM_ACVP_STATUS.md` |
| Decaps-toggle-mittaus: valinta- ja vertailulogiikka | Mitattu validoidulla työkalulla | Kerta-ajo, `toggle-proxy/` |
| TRNG | Ei toteutettu | — |
| Lint (Verilator `-Wall`), Yosys-synteesi NTT- ja Keccak-ytimille | — | CI |

### TAU-kehys (`hardware/pqc-rtl/fpga/tau/`)

| Osa | Tila | Todennus |
|---|---|---|
| Wishbone-väyläohjaus, ML-KEM KeyGen/Encaps/Decaps-orkestrointi, hash-ketjutettu audit-loki (SHA3-256), watchdog | Toteutettu RTL:nä | CI: 8 simulaatiotestiä (`run_m4_tau_*`) |
| Synteesi ja P&R kokonaisuutena | Ei tehty | — |

### ML-DSA-65 RTL (`hardware/pqc-rtl/dilithium-rtl/`)

| Osa | Tila | Todennus |
|---|---|---|
| KeyGen, `Sign_internal`, `Verify_internal` | Synteesikelpoinen SystemVerilog | CI: Verify (positiivinen, negatiiviset, monisiemen), Sign-primitiivit ja -vaiheet `dilithium-py`-referenssiä vasten; KeyGen ACVP-vektorilla |
| Koko Sign (hylkäyssilmukka ja pakkaus) | — | Vain käsin käynnistettävä `dilithium-heavy-integration.yml` |
| NIST ACVP: KeyGen, Verify, Sign, yksi vektori kukin | PASS | CI: KeyGen ja Verify (`run_acvp_dilithium.sh`). Sign: käsin käynnistettävä workflow. `dilithium-rtl/NIST_ACVP_STATUS.md` |
| Rakennuspalikoiden synteesi (Barrett, NTT-ytimet, decompose, make_hint, pack) | Tehty yksitellen | `dilithium-rtl/SYNTHESIS_REPORT.md` |
| Päätason synteesi, ECP5 P&R, Fmax | Ei tehty | — |
| Viestin enimmäispituus | 136 tavua (yksi SHAKE256-lohko) | `dilithium-rtl/NIST_ACVP_STATUS.md` |

### RISC-V-ohjelmistotyö (`hardware/pqc-rtl/rvv*`, `tvm-riscv/`, `oqs-rvv-provider/`)

| Osa | Tila | Todennus |
|---|---|---|
| `rvv/`: ML-KEM:n Montgomery-reduktio RVV-intrinsiikeillä | Yksi funktio | CI: QEMU, VLEN 128 ja 256 |
| `rvv-dilithium/`: ML-DSA-65:n avaingenerointi, allekirjoitus ja verifiointi (C + RVV) | Bittitarkka pq-crystals-referenssiin | CI: NTT-testi QEMU:ssa; koko API:n vertailu `rvv-dilithium/README.md` |
| `tvm-riscv/` (TVM-malli RISC-V:lle), `oqs-rvv-provider/` (OpenSSL-providerin runko) | Kokeilu | CI: käännös ja ajo QEMU:ssa |

### Konseptit (`concept/`)

TrustCore NX (oma RISC-V-SoC), Aether OS, fyysinen laite ja muut `concept/`-kansion sisällöt
ovat konsepteja. Niistä ei ole toteutusta tässä repossa, lukuun ottamatta
`concept/lex-resiliens/`-kehystä, jonka kolme testisarjaa ajetaan CI:ssä.

## Mitä tämä ei ole

- Ei sertifioitu eikä FIPS-validoitu. ACVP-vektorien läpäisy ei ole CAVP-validointi.
- Ei ajettu fyysisellä FPGA-laudalla.
- Ei sivukanavasuojattu teho- tai EM-analyysiä vastaan.
- RTL-ytimiä ei ole kytketty Pi-prototyyppiin; Pi allekirjoittaa ohjelmistolla.
- NTT-ydin on noin 30 kertaa hitaampi kuin Pi 5:n CPU. Tämä on dokumentoitu rajaus.

## Rakenne

```
pi2_trust_server/      Trust Server (Pi 2 Model B)
pi5_edge_node/         Edge Node (Pi 5)
hardware/pqc-rtl/      RTL, golden-mallit, testipenkit, FPGA-raportit, RVV-työ
concept/               Konseptit
KORJAUSLISTA.md        Avoimet kohdat
PROJECT_STATUS_AND_DIRECTION.md   Suunta ja päätökset
ROADMAP.md             Vaiheet
INSTALL.md, QUICKSTART.md, NETWORK_SETUP.md   Pi-asennus
```

## Ajaminen

RTL-testit (Icarus Verilog):

```bash
bash hardware/pqc-rtl/run_m3_kpke_roundtrip_test.sh
bash hardware/pqc-rtl/run_m4_tau_full_protocol_test.sh
```

Pi-prototyyppi: ks. `INSTALL.md`. Asennus vaatii `git`, `cmake`, `ninja-build`, `build-essential` ja `libssl-dev`.

ACVP-regressio:

```bash
bash hardware/pqc-rtl/run_acvp_mlkem.sh
```

## Raportointi

Statusdokumentit noudattavat `hardware/pqc-rtl/REPORTING-DISCIPLINE.md`:n sääntöjä:
tulos ilman arvottamista, ei oman työn merkityksen arviointia samassa dokumentissa,
konvergenssia ei kutsuta vahvistukseksi. Ennen 2026-07-21 kirjoitetut dokumentit eivät
noudata näitä (KORJAUSLISTA E1).

## Lisenssi

Ks. `LICENSE`.

---
*Aether Continuity Institute · 2026*
