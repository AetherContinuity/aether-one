# Korjauslista

**Päivitetty:** 2026-10-02

Avoimet kohdat yhdessä paikassa. Jokaisella rivillä on lähde, josta kohta
on peräisin; tämä tiedosto ei lisää uusia havaintoja niiden päälle, paitsi
osiossa A (dokumenttien ja koodin ristiintarkistus 2026-10-02).

Järjestys osion sisällä ei ole prioriteetti.

## A. Dokumentit ja koodi eivät vastaa toisiaan (tarkistus 2026-10-02)

| # | Kohta | Tila |
|---|---|---|
| A1 | `requirements.txt` ei sisältänyt `liboqs-python`-pakettia, vaikka `crypto.py` tarvitsee sen. | Korjattu 2026-10-02: `install.sh` kutsuu `install_liboqs.sh`:ta, joka rakentaa liboqs:n (vain ML-DSA-65) ja ajaa allekirjoitus- ja verifiointi-itsetestin; asennus keskeytyy, jos testi ei mene läpi. Testattu x86-Linuxilla ja CI:ssä (`test-pi-installer`). **Ei testattu Raspberry Pi:llä (ARM).** |
| A2 | `pycryptodome` oli `requirements.txt`-tiedostoissa käyttämättömänä. | Poistettu 2026-10-02 |
| A3 | "TrustCore v1.0 C-kernel" mainittiin valmiina (ROADMAP, INSTALL). Repossa ei ole C-ydintä: `pi5_edge_node/core/kri_engine.py` toteaa itse, että `trustcore_native/libtrustcore.so` puuttuu. `crypto.py`:n oma otsikko on "TrustCore v0.1". | Dokumentit korjattu 2026-10-02; ydin puuttuu |
| A4 | Latenssi- ja kuormaluvut ("<10 ms PQC verify", "<50 ms sensor → KRI", "~5 % CPU") olivat INSTALL.md:ssä ilman mittausta repossa. | Poistettu 2026-10-02; mittaus puuttuu |
| A5 | QUICKSTART.md viittaa zip-paketteihin (`aether_one_dual_pi_complete.zip` ym.), joita repossa ei ole. | Avoin |
| A6 | NIST ACVP -ajot eivät olleet `verify.yml`:ssä. | Korjattu 2026-10-02: `run_acvp_mlkem.sh` (KeyGen 1, Encaps 3, Decaps 5 ja kolme negatiivikontrollia) ja `run_acvp_dilithium.sh` (KeyGen, Verify) ajetaan jokaisella pushilla. ML-DSA Sign -ACVP on edelleen vain käsin käynnistettävässä workflow'ssa. |
| A7 | `hardware/pqc-rtl/README.md`:n otsikko ja johdanto kuvaavat kansion NTT256-kiihdyttimeksi; sisältö on koko ML-KEM-512, TAU-kehys ja ML-DSA-65. | Avoin |
| A8 | `CHANGELOG.md` päättyy M3 RC1:een (2026-07-14). M4-FPGA, M4-TAU, orkestrointi, ACVP ja ML-DSA-RTL eivät ole siinä. | Avoin |
| A9 | Issue #17 (M5-DILITHIUM-001) on auki. Toiminnallinen RTL ja ACVP-ankkurointi on tehty; issuen jäljellä oleva sisältö on osion C kohdat. | Avoin |
| A10 | Ennen 2026-10-02 tallennettujen ML-KEM Encaps- (1 kpl) ja Decaps-vektorien (5 kpl) lähdecommitia `usnistgov/ACVP-Server`:ssä ei ole kirjattu. NIST:n `encapDecap`-esimerkkitiedosto on sittemmin generoitu uudelleen: vektoreita ei löydy nykyisestä tiedostosta. KeyGen-vektori vastaa commitin 975de31 tcId=1:tä. Uudet Encaps-vektorit (tcId 1–3) on sidottu commitiin, ks. `hardware/pqc-rtl/fpga/tau/acvp/README.md`. | Avoin |

## B. ML-KEM-512 RTL (`hardware/pqc-rtl/rtl/`, `fpga/`)

| # | Kohta | Lähde |
|---|---|---|
| B1 | Vain K=2 (ML-KEM-512). ML-KEM-768/1024 ei todennettu. | `M3_MLKEM_ACVP_STATUS.md`, `CHANGELOG.md` |
| B2 | TRNG puuttuu. Testataan vain `_internal`-versioita, joissa satunnaisuus annetaan testivektorina. | `FIPS203_COVERAGE.md` |
| B3 | ACVP-kattavuus: KeyGen 1 vektori, Encaps 3, Decaps 5. NIST:n tiedostossa on ML-KEM-512:lle 25 Encaps- ja 10 Decaps-tapausta sekä avaintarkistusryhmät, joita ei ajeta. | `M3_MLKEM_ACVP_STATUS.md` |
| B4 | ECP5-synteesi ja P&R on tehty NTT-ytimelle (ja Wishbone-kääreelle synteesi). KeyGen-, Encaps- ja Decaps-orkestrointiytimien synteesi ei valmistunut työympäristön resurssirajoissa. Keccak-instanssien jakamista ei ole toteutettu. | `fpga/tau/M4_DECAPS_ORCH_001_STATUS.md` (jatko 11), `M4_TAU_001_MILESTONE.md` |
| B5 | Fmax 30,40 MHz koskee NTT-ydintä (ECP5-25k, 1 pipeline-vaihe). Koko ML-KEM:n Fmax ei tiedossa. | `fpga/timing_reports/M4_FPGA_006_ANALYSIS.md` |
| B6 | Ei ajettu fyysisellä FPGA-laudalla. | Repossa ei ole laiteajon kirjausta |
| B7 | Sivukanavat: Decaps on syklitasolla vakioaikainen salaisen datan suhteen (saman avaimen vertailu). Toggle-mittaus kattaa valinta- ja vertailulogiikan. Ulostuloarvon Hamming-painovaihtelu vaatisi maskauksen; teho- tai EM-mittausta ei ole tehty. | `M3_MLKEM_ACVP_STATUS.md` |
| B8 | Ajoitus- ja toggle-mittauksen otos on yksi avain (tcId=76) ja yksi valid/rejection-pari; korruptio on yksi tavu. Laajempaa otosta (useita avaimia, useita hylkäystapauksia) ei ole ajettu. | `M3_MLKEM_ACVP_STATUS.md` |

## C. ML-DSA-65 RTL (`hardware/pqc-rtl/dilithium-rtl/`)

| # | Kohta | Lähde |
|---|---|---|
| C1 | ACVP-kattavuus: yksi vektori per operaatio (KeyGen tcId=26, Verify tcId=140, Sign tcId=139). Signin yksikierroksinen (kappa=0) NIST-tapaus puuttuu. | `dilithium-rtl/NIST_ACVP_STATUS.md` |
| C2 | Viestipuskuri on yksi SHAKE256-lohko (136 tavua). sigVer:n `testPassed=True`-tapaukset (pienin 2027 tavua) eivät mahdu. Sama `MAX_BLOCKS`-rajoite koskee todennäköisesti Signin mu-laskentaa. | `dilithium-rtl/NIST_ACVP_STATUS.md` |
| C3 | Päätason (KeyGen/Sign/Verify) LUT/FF-määrää ei ole mitattu. Rakennuspalikat on syntesoitu yksitellen. | `dilithium-rtl/SYNTHESIS_REPORT.md` |
| C4 | ECP5-kohdekohtaista synteesiä ja P&R:ää ei ole tehty. Fmax ei tiedossa; looginen kriittinen polku 107 tasoa Barrett-mulmodissa. | `dilithium-rtl/SYNTHESIS_REPORT.md` |
| C5 | Ei TAU-kehysintegraatiota (Wishbone, audit-loki, watchdog) ML-DSA:lle. | `PROJECT_STATUS_AND_DIRECTION.md` |
| C6 | Toteuttaa `_internal`-rajapinnat (`Sign_internal`, `Verify_internal`), ei ulkoista API:a. | `dilithium-rtl/NIST_ACVP_STATUS.md` |

## D. Arkkitehtuuri

| # | Kohta | Lähde |
|---|---|---|
| D1 | Turvatasojen epäsuhta: ML-KEM-512 (kategoria 1) ja ML-DSA-65 (kategoria 3) samassa järjestelmässä. Ratkaisematta. Hinta kasvaa jokaisen K=2-oletukseen sidotun testipenkin myötä. | `PROJECT_STATUS_AND_DIRECTION.md` |
| D2 | NTT-ydin on noin 30 kertaa hitaampi kuin Pi 5:n CPU. Dokumentoitu rajaus; arvioitava uudelleen ensimmäisenä, jos suunta muuttuu kohti laitepolkua. | `PROJECT_STATUS_AND_DIRECTION.md` |
| D3 | Pi-prototyyppi allekirjoittaa ohjelmistolla (liboqs). RTL-ytimiä ei ole kytketty Pi-pinoon. | `README.md` |

## E. Raportointikuri

| # | Kohta | Lähde |
|---|---|---|
| E1 | Superlatiivit ja oman työn arvottaminen ovat läpileikkaavia ennen 2026-07-21 kirjoitetuissa statusdokumenteissa (DK1–DK6, SYNTHESIS_REPORT, M4-sarja). Niitä ei ole kirjoitettu uudelleen; se on erillinen päätös. | `hardware/pqc-rtl/REPORTING-DISCIPLINE.md` |
| E2 | `check_reporting_discipline.sh` kattaa kolme dokumenttia. Juuren `README.md`:n tilataulukko ei ole listalla. | `hardware/pqc-rtl/check_reporting_discipline.sh` |
