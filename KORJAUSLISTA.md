# Korjauslista

**Päivitetty:** 2026-11-16

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
| A5 | QUICKSTART.md viittaa zip-paketteihin (`aether_one_dual_pi_complete.zip` ym.), joita repossa ei ole. | Korjattu 2026-11-15: vaihe 1 on `git clone`. |
| A6 | NIST ACVP -ajot eivät olleet `verify.yml`:ssä. | Korjattu 2026-10-02: `run_acvp_mlkem.sh` (KeyGen 1, Encaps 3, Decaps 5 ja kolme negatiivikontrollia) ja `run_acvp_dilithium.sh` (KeyGen, Verify) ajetaan jokaisella pushilla. ML-DSA Sign -ACVP on edelleen vain käsin käynnistettävässä workflow'ssa. |
| A7 | `hardware/pqc-rtl/README.md`:n otsikko ja johdanto kuvaavat kansion NTT256-kiihdyttimeksi; sisältö on koko ML-KEM-512, TAU-kehys ja ML-DSA-65. | Korjattu 2026-11-15: otsikko ja sisältöluettelo; milestone-taulukko merkitty historialliseksi. |
| A8 | `CHANGELOG.md` päättyy M3 RC1:een (2026-07-14). M4-FPGA, M4-TAU, orkestrointi, ACVP ja ML-DSA-RTL eivät ole siinä. | Korjattu 2026-11-15: tiivis merkintä per vaihe lähdedokumentteineen. |
| A9 | Issue #17 (M5-DILITHIUM-001) on auki. Toiminnallinen RTL ja ACVP-ankkurointi on tehty; issuen jäljellä oleva sisältö on osion C kohdat. | Avoin |
| A11 | ~~Kaksi testipenkkiä (`pqc_mlkem_decaps_b1_core_tb.sv`, `pqc_mlkem_decaps_b4_allcases_tb.sv`) epäonnistuu.~~ **Syy 2026-11-16:** ne lukevat generoidun (gitignore) `vectors/mlkem_decaps_b_vectors.txt`:n, jonka vain `run_m3_mlkem_decaps_b_test.sh` luo. Ilman sitä `$fopen` palautti 0, ja 10/3 vertailua epäonnistui; samalla osa vertailuista (c', K_final) raportoi OK X-arvoilla. RTL:ssä ei vikaa: generoinnin jälkeen kaikki vaiheet täsmäävät. Korjattu: tiedoston puuttuminen on virhe, `run_m4_decaps_b_core_test.sh` CI:ssä. | Korjattu 2026-11-16 |
| A12 | ~~`decaps_nist_multi_tb.sv` ei tarkista `$fscanf`-paluuarvoja.~~ Todennettu: 6 ilmoitettua, 5 tiedostossa → PASS. Korjattu 2026-11-16; `run_acvp_mlkem.sh` ja `run_acvp_mlkem_full.sh` ajavat nyt vajaan tiedoston negatiivikontrollin jokaiselle operaatiolle. | Korjattu 2026-11-16 |
| A13 | 138 testipenkkitiedostoa avaa tiedostoja tarkistamatta kahvaa. Icarus jatkaa virheellisellä kahvalla, odotusarvot jäävät X:iksi, ja X === X läpäisee. Lievennys 2026-11-16: CI ajaa `vvp`:n kääreen `tools/vvp-tarkka/vvp` kautta, joka epäonnistuu tiedostovirheestä. CI:n 26 testiskriptiä ajettiin kääreen kanssa paikallisesti: yhtään tiedostovirhettä ei ollut (kolme raskasta ML-DSA-skriptiä aikakatkaistiin rinnakkaisajossa, ne ajetaan CI:ssä). Testipenkit itse ovat ennallaan; CI:n ulkopuolinen ajo ilman käärettä on yhä altis. | Lievennetty |
| A10 | Ennen 2026-10-02 tallennettujen ML-KEM Encaps- (1 kpl) ja Decaps-vektorien (5 kpl) lähdecommitia `usnistgov/ACVP-Server`:ssä ei ole kirjattu. NIST:n `encapDecap`-esimerkkitiedosto on sittemmin generoitu uudelleen: vektoreita ei löydy nykyisestä tiedostosta. KeyGen-vektori vastaa commitin 975de31 tcId=1:tä. Uudet Encaps-vektorit (tcId 1–3) on sidottu commitiin, ks. `hardware/pqc-rtl/fpga/tau/acvp/README.md`. | Avoin |

## B. ML-KEM-512 RTL (`hardware/pqc-rtl/rtl/`, `fpga/`)

| # | Kohta | Lähde |
|---|---|---|
| B1 | ~~Vain K=2.~~ Korjattu: ytimet ja `pqc_tau_integrated_wrapper` K-parametrisia, **oletus K=3 (ML-KEM-768) 2026-11-16**. K=2 ja K=3: kaikki NIST ACVP -tapaukset; 8 TAU-testiä (`run_m4_tau_*`) ajetaan molemmilla. K=4 (ML-KEM-1024) kääntyy, ei todennettu. | `M3_MLKEM_ACVP_STATUS.md` |
| B2 | TRNG puuttuu. Testataan vain `_internal`-versioita, joissa satunnaisuus annetaan testivektorina. | `FIPS203_COVERAGE.md` |
| B3 | ~~KeyGen 1, Encaps 3, Decaps 5.~~ 2026-11-15: kaikki KeyGen- (25), Encaps- (25) ja Decaps-tapaukset (10) sekä K=2:lle että K=3:lle, synteesikelpoisia ytimiä vasten, CI:ssä. Avaintarkistusryhmiä (`encapsulationKeyCheck`, `decapsulationKeyCheck`) ei ajeta: RTL ei toteuta FIPS 203:n 7.2/7.3-syötetarkistuksia. | `M3_MLKEM_ACVP_STATUS.md` |
| B4 | Orkestrointiytimien synteesi ei valmistunut. **Syy selvitetty 2026-11-16:** ytimet pitävät jokaisen polynomin rinnakkaisrekisterissä. Yosys: `decaps_a_core` (pienin) 82 330 FF-bittiä omalla tasollaan, arvio 84 952 (97 %); koko kääre arviolta ≈ 685 000. LFE5U-25F:ssä 24 288 ja 85F:ssä 83 640 FF:ää: nykyinen arkkitehtuuri ei mahdu kumpaankaan. Korjaus vaatii arkkitehtuurimuutoksen (polynomit BRAM:iin, virtaava koodaus, A sarake kerrallaan, jaettu Keccak/NTT). | `hardware/pqc-rtl/b4/B4-ENNAKKO.md`, `B4-TULOS.md` |
| B5 | Fmax 30,40 MHz koskee NTT-ydintä (ECP5-25k, 1 pipeline-vaihe). Koko ML-KEM:n Fmax ei tiedossa. | `fpga/timing_reports/M4_FPGA_006_ANALYSIS.md` |
| B6 | Ei ajettu fyysisellä FPGA-laudalla. | Repossa ei ole laiteajon kirjausta |
| B7 | Sivukanavat: Decaps on syklitasolla vakioaikainen salaisen datan ja ciphertextin sisällön suhteen, ja valintamekanismi ei lisää bittikytkentää valitun ehdokkaan päälle (RTL-simulaatio, B8:n otos). Ulostuloarvon Hamming-painovaihtelu vaatisi maskauksen; teho- tai EM-mittausta ei ole tehty. | `hardware/pqc-rtl/sivukanava/B8-TULOS.md` |
| B8 | ~~Otos yksi avain ja yksi valid/hylkäys-pari.~~ **2026-11-16:** 20 NIST-avainta (K=2, K=3), 5–6 ciphertext-muunnelmaa ja salaisuudenvaihto per avain, 130 ajoa + 18 toggle-ajoa; ennakkorekisteröity, kaikki neljä hypoteesia pätevät; kolme tarkoituksella vuotavaa muunnelmaa havaittiin. CI:ssä regressiona. | `hardware/pqc-rtl/sivukanava/B8-ENNAKKO.md`, `B8-TULOS.md` |

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
| D1 | ~~Turvatasojen epäsuhta ML-KEM-512 / ML-DSA-65.~~ **Ratkaistu 2026-11-16:** ML-KEM-768 + ML-DSA-65 (molemmat kat. 3), RTL:n oletus K=3. | `PROJECT_STATUS_AND_DIRECTION.md` |
| D2 | NTT-ydin on noin 30 kertaa hitaampi kuin Pi 5:n CPU. Dokumentoitu rajaus; arvioitava uudelleen ensimmäisenä, jos suunta muuttuu kohti laitepolkua. | `PROJECT_STATUS_AND_DIRECTION.md` |
| D3 | Pi-prototyyppi allekirjoittaa ohjelmistolla (liboqs). RTL-ytimiä ei ole kytketty Pi-pinoon. | `README.md` |

## E. Raportointikuri

| # | Kohta | Lähde |
|---|---|---|
| E1 | Superlatiivit ja oman työn arvottaminen ovat läpileikkaavia ennen 2026-07-21 kirjoitetuissa statusdokumenteissa (DK1–DK6, SYNTHESIS_REPORT, M4-sarja). Niitä ei ole kirjoitettu uudelleen; se on erillinen päätös. | `hardware/pqc-rtl/REPORTING-DISCIPLINE.md` |
| E2 | ~~Juuren `README.md` ei ole listalla.~~ Korjattu 2026-11-15: lisätty juuren `README.md` ja `KORJAUSLISTA.md`; puuttuva tiedosto on nyt virhe (aiemmin ohitettiin hiljaa). | `hardware/pqc-rtl/check_reporting_discipline.sh` |
