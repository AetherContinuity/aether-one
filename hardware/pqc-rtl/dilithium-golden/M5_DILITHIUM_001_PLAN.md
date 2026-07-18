# M5-DILITHIUM-001: suunnitteludokumentti

**Paivamaara:** 2026-07-19
**Tila:** SUUNNITTELUVAIHE - ei viela RTL-tyota aloitettu.
**Vastaa:** GitHub Issue #17

## 1. Mita jo on olemassa

### 1.1 Ohjelmistoreferenssi (rvv-dilithium/)

`hardware/pqc-rtl/rvv-dilithium/` sisaltaa TAYDEN, bittitarkasti
pq-crystals/dilithium-referenssia vasten todennetun ML-DSA-65-
toteutuksen C:lla + RVV-intrinsiiceilla (QEMU-emulointi). Tama
todistaa etta KOKO algoritmi (KeyGen+Sign+Verify+pakkaus) on
YMMARRETTY OIKEIN ja toteutettavissa - mutta se on OHJELMISTOA,
ei RTL:aa, eika sita voi kayttaa suoraan synteesikelpoisen
orkestroinnin pohjana (RVV-vektori-intrinsiicit eivat kaanny
suoraan SystemVerilogiksi).

**Arvokkain anti taalta:** dokumentoidut, jo LOYDETYT JA KORJATUT
bugit (ks. oma osio 4 alla) - nama kertovat etukateen mihin
kannattaa varautua.

### 1.2 UUSI: Python-golden-malli (dilithium-golden/)

Taman suunnitteluistunnon aikana asennettiin ja todennettiin
`dilithium-py`-paketti (GiacomoPope/dilithium-py, PyPI) VIRALLISENA,
riippumattomana FIPS 204 -referenssina. Tama tayttaa saman roolin
kuin `m2-golden/` teki ML-KEM-tyossa - EI kuitenkaan saa unohtaa
ML-KEM-tyon TARKEINTA metodologista oppia (ks. osio 5).

Vahvistettu toimivaksi ja deterministiseksi:
```python
from dilithium_py.ml_dsa import ML_DSA_65
pk, sk = ML_DSA_65._keygen_internal(zeta)   # 32-tavuinen zeta
sig = ML_DSA_65._sign_internal(sk, m, rnd)
valid = ML_DSA_65._verify_internal(pk, m, sig)
```

pk=1952 tavua, sk=4032 tavua, sig=3309 tavua - tasmaa ML-DSA-65:n
omiin, tunnettuihin kokoihin.

## 2. ML-DSA-65:n parametrit (vahvistettu)

| Parametri | Arvo | Vertailu ML-KEM-512:een |
|---|---|---|
| N (polynomin aste) | 256 | sama |
| Q (moduli) | 8380417 | ERI (ML-KEM: 3329) - 23-bittinen, ei 12-bittinen |
| K (rivit) | 6 | ML-KEM: 2 - 3x suurempi matriisi |
| L (sarakkeet) | 5 | ML-KEM: 2 (K=L siella) |
| ETA | 4 | ML-KEM: 2-3 |
| GAMMA1 | 2^19 | Uusi kasite (naamiointi) |
| GAMMA2 | (Q-1)/32 | Uusi kasite (Decompose) |
| TAU | 49 | Uusi (SampleInBall-painoraja) |
| BETA | TAU*ETA=196 | Uusi (allekirjoituksen normiraja) |
| OMEGA | 55 | Uusi (hint-painoraja) |
| D | 13 | Uusi (Power2Round-bittimaara) |

**KESKEISIN ERO:** Montgomery-aritmetiikka on 32-bittinen
(R=2^32), EI 16-bittinen kuten ML-KEM:ssa - KOKO NTT-ydin, butterfly-
logiikka ja muistin sanaleveys pitaa suunnitella UUDELLEEN, EI
uudelleenkayttaa suoraan `pqc_ntt_stage_banked.sv`:aa sellaisenaan.

## 3. Algoritmin rakenne (FIPS 204)

### 3.1 ML-DSA.KeyGen (Algoritmi 1) - suhteellisen suoraviivainen

1. Puretaan siemen (rho, rho', K-avain) H-funktiolla (SHAKE256)
2. ExpandA(rho) -> A-matriisi (K*L = 30 polynomia, EI 4 kuten ML-KEM:ssa!)
3. ExpandS(rho') -> s1 (L=5 polynomia), s2 (K=6 polynomia) - CBD:n
   sijaan RejSample ETA:lle (eri nayttestysmenetelma kuin ML-KEM:n CBD)
4. t = NTT^-1(A * NTT(s1)) + s2
5. Power2Round(t) -> t1 (julkinen), t0 (salainen, D=13 bittia)
6. tr = H(pk), pakkaa pk=(rho,t1), sk=(rho,K,tr,s1,s2,t0)

**Rakenteellisesti samankaltainen kuin ML-KEM.KeyGen** (matriisin
generointi + nayttestys + matriisikertolasku + pakkaus) - mutta
SUUREMPI matriisi (30 vs 4 polynomia) ja ERI nayttestys (RejSample
ETA:lle CBD:n sijaan).

### 3.2 ML-DSA.Sign (Algoritmi 2) - UUSI HAASTE: hylkayssilmukka

TAMA ON RAKENTEELLISESTI UUSI VERRATTUNA MIHINKAAN ML-KEM-TYOHON:
Sign-algoritmi on SILMUKKA joka voi toistua USEITA KERTOJA (rvv-
dilithium:n oma testi tarvitsi 9 yritysta) kunnes tuotettu
allekirjoitus lapaisee KOLME hylkaysehtoa:

1. mu = H(tr || M), rhoPrimePrime = H(K || rnd || mu)
2. **Silmukka alkaa (kappa=0,1,2...):**
   a. y = ExpandMask(rhoPrimePrime, kappa) - GAMMA1-rajattu naytto
   b. w = NTT^-1(A * NTT(y)), w1 = HighBits(w)
   c. c_tilde = H(mu || w1), c = SampleInBall(c_tilde)
   d. z = y + c*s1
   e. **HYLKAYSEHTO 1:** ||z||_inf >= GAMMA1-BETA -> UUSI YRITYS
   f. r0 = LowBits(w - c*s2)
   g. **HYLKAYSEHTO 2:** ||r0||_inf >= GAMMA2-BETA -> UUSI YRITYS
   h. h = MakeHint(-c*t0, w - c*s2 + c*t0)
   i. **HYLKAYSEHTO 3:** ||c*t0||_inf >= GAMMA2 TAI hintien maara > OMEGA -> UUSI YRITYS
3. Jos kaikki lapaisevat: palauta sig=(c_tilde,z,h)

**Tama silmukka on synteesikelpoisen orkestroinnin kannalta
GENUINE UUSI ONGELMA** - ML-KEM:ssa mikaan vaihe ei koskaan
"epaonnistunut ja aloittanut alusta" (paitsi FO-hylkays Decapsissa,
mutta se EI toista koko laskentaa, vain vaihtaa lopputulosta). Tassa
KOKO vaiheen 2 laskenta pitaa PYSTYA TOISTAMAAN eri kappa-arvolla,
mahdollisesti MONTA KERTAA, synteesikelpoisessa tilakoneessa.

### 3.3 ML-DSA.Verify (Algoritmi 3) - suoraviivaisin

1. Pura pk=(rho,t1), sig=(c_tilde,z,h)
2. Tarkista ||z||_inf < GAMMA1-BETA
3. c = SampleInBall(c_tilde)
4. w1' = UseHint(h, A*NTT(z) - c*NTT(t1)*2^D)
5. Tarkista c_tilde == H(mu || w1') JA hintien maara <= OMEGA

Rakenteellisesti lahinna KeyGenia (ei silmukkaa) - VERROLLINEN
tyomaara ML-KEM.Decaps:n Phase A:han (yksi kierros, ei retryta).

## 4. Tunnetut, jo dokumentoidut sudenkuopat (rvv-dilithium:sta)

Nama LOYDETTIIN JA KORJATTIIN jo kertaalleen ohjelmistotasolla -
todennakoisesti TOISTUVAT RTL-tyossa, joten kannattaa TARKISTAA
NAMA NIMENOMAAN ETUKATEEN:

1. **Vaara Kyber/ML-DSA-parametrisekaannus** - 16-bittinen vs.
   32-bittinen Montgomery. (Jo tiedossa, ks. osio 2.)
2. **Vaara Montgomery-etumerkkikonventio** (loytyi KAHDESTI eri
   kohdissa) - 32-bittisen Montgomery-reduktion oma etumerkin-
   kasittely eroaa 16-bittisesta.
3. **Vaara nonce-kaava:** `L*kappa+i` (EI juokseva laskuri) -
   ExpandMask/y-nayttestyksen oma indeksointi.
4. **Vaara parametrijarjestys pack_sk:ssa** - funktion PARAMETRI-
   NIMET voivat harhauttaa; runko voi kirjoittaa ERI jarjestyksessa
   kuin nimet antavat ymmartaa. TARKISTA AINA runko, ei vain
   allekirjoitus.
5. **VAKAVIN: kaksi eri avainparia** - `t0` ei ollut sama
   allekirjoituksessa ja verifioinnissa. Tama on ANALOGINEN sille
   A-matriisin transpoosi-sekaannukselle joka loydettiin Decaps-
   tyossa (ks. osio 5) - molemmat ovat "arvo nayttaa oikealta
   mutta on VAARASSA PAIKASSA/VAARASSA MUODOSSA" -tyyppisia bugeja.

## 5. TARKEIN metodologinen muistutus (ML-KEM-tyosta, EI SAA UNOHTAA)

**Decaps-tyon oma, vakavin loydos:** ensimmainen "A-matriisin
transpoosi-korjaus" oli VAARIN, koska sita verrattiin OMAAN,
manuaalisesti uudelleentoteutettuun Python-referenssiin joka JAKOI
SAMAN vaaran oletuksen RTL:n kanssa. Todellinen korjaus loytyi VASTA
vertaamalla TAYSIN riippumattomaan, viralliseen `kpke_encrypt()`-
funktioon.

**Taman tyopaketin kannalta:** `dilithium-py` ITSESSAAN on se
riippumaton, virallinen vertailukohta - EI mikaan oma manuaalinen
uudelleentoteutuksemme. JOKAINEN RTL-vaiheen golden-vertailu pitaa
lopulta KAYTTAA `dilithium-py`:n omia sisaisia funktioita SUORAAN,
EI omaa Python-uudelleenkirjoitustamme niiden ymparille (paitsi
valivaiheiden PILKKOMISEEN, jolloin PILKOTUT VALIARVOT on
ristiinvarmistettava tallä kirjastolla, EI vain sisaisella
johdonmukaisuudella).

## 6. Uudelleenkaytettava infrastruktuuri (ML-KEM-tyosta)

Suoraan hyodynnettavissa ilman muutoksia:
- **SHA3-256/SHA3-512/SHAKE128/SHAKE256-ytimet** (`pqc_sha3_256.sv`
  jne.) - Dilithium kayttaa SAMOJA hajautusfunktioita, EI omia.
- **Wishbone-vaylakaare + audit-loki + watchdog** - sama
  WORD_SEL->START->STATUS->READ BACK -malli, sama audit-tapahtuma-
  arkkitehtuuri (KEYGEN/DECAPS/ENCAPS_STARTED/COMPLETED/WATCHDOG_
  INTERRUPTED -kaava toistuu suoraan DILITHIUM_KEYGEN/SIGN/VERIFY_*
  -versioina).
- **CI-testauskehys** (run_*.sh + workflow-mallit).
- **Metodologia:** vaiheittainen orkestrointi, jokainen vaihe
  golden-referenssia vasten ennen seuraavaan siirtymista - sama
  kurinalaisuus joka toimi KeyGenille ja Decapsille.

EI suoraan uudelleenkaytettavissa (uutta suunnittelutyota vaativaa):
- **NTT-ydin** - 32-bittinen Montgomery, 23-bittinen Q, ERI
  butterfly-parametrit (zeta-taulukot, moduloaritmetiikka).
- **Nayttestysmenetelmat** - RejSample (ETA) ja ExpandMask (GAMMA1)
  eroavat ML-KEM:n CBD:sta.
- **Hylkayssilmukka** - EI VASTINETTA ML-KEM:ssa, oma, uusi
  tilakonerakenne tarvitaan (silmukan oma "epaonnistui, aloita
  uudella kappa:lla" -ohjaus).
- **Hint-koodaus, Decompose/HighBits/LowBits, Power2Round** - uusia
  kasitteita, ei ML-KEM:ssa vastinetta.

## 7. Ehdotettu vaiheistus (kayttajan oman B1-B4-tyylisen jaon mukaisesti)

### M5-DILITHIUM-KEYGEN (ensimmainen, todennakoisin lahtokohta)

Rakenteellisesti lahinna jo tuttua tyota (matriisi+nayttestys+
matriisikertolasku+pakkaus, KUTEN ML-KEM.KeyGen), mutta 32-bittisella
aritmetiikalla ja isommalla matriisilla (30 polynomia 4:n sijaan).

- **DK1:** 32-bittinen NTT-ydin (uusi butterfly, uusi zeta-ROM) -
  todennettava ERIKSEEN ennen mitaan muuta, samaan tapaan kuin
  ML-KEM:n oma NTT todennettiin ensin M1/M2-vaiheissa.
- **DK2:** ExpandA (SHAKE128-pohjainen nayttestys, K*L=30 polynomia)
- **DK3:** ExpandS (RejSample ETA:lle, L+K=11 polynomia)
- **DK4:** Matriisikertolasku + Power2Round + pakkaus

### M5-DILITHIUM-VERIFY (toinen - EI silmukkaa, suoraviivaisin)

Rakenteellisesti lahinna Decaps Phase A:ta (yksi kierros).

### M5-DILITHIUM-SIGN (kolmas, VAIKEIN - sisaltaa hylkayssilmukan)

Vasta kun KeyGen+Verify ovat vankalla pohjalla. Oma, erillinen
suunnittelukysymys: miten hylkayssilmukka toteutetaan synteesi-
kelpoisena tilakoneena (todennakoisesti: ulompi FSM-kerros joka
kutsuu sisemman FSM:n uudelleen kappa+1:lla epaonnistuessa,
rajallisella max-yrityskertaluvulla turvallisuussyista).

## 8. Suorituskykymittarit (maaritelty ETUKATEEN, kayttajan oma huomio)

**Kayttajan oma perustelu:** ML-KEM-projektissa mittarit (Fmax,
solumaara, syklit/NTT, us/operaatio) osoittautuivat hyodyllisiksi
VASTA jalkikateen (M4-FPGA-005..008). Dilithium-tyolle maaritellaan
samat mittarikategoriat NYT, suunnitteluvaiheessa, jotta jokainen
tyopaketti (KeyGen/Verify/Sign) voidaan arvioida VERTAILUKELPOISESTI
alusta asti, samoin kuin koko TAU-kehyksen myohempi dokumentointi
helpottuu.

### 8.1 Mitattavat suureet

| Mittari | Mittaustapa | ML-KEM:n oma vertailuarvo |
|---|---|---|
| Syklit / NTT (32-bit) | Simulaatio, kiintea syote | ML-KEM: 448 sykli/NTT-taso * 7 tasoa (READ_LATENCY=1) |
| Syklit / KeyGen | Simulaatio, kiintea siemen | ML-KEM.KeyGen: 11336 sykli |
| Syklit / Verify | Simulaatio, kiintea (pk,m,sig) | ML-KEM.Decaps (verrannollinen, ei silmukkaa): ~7288 sykli |
| Syklit / Sign | Simulaatio, **KESKIARVO JA VAIHTELUVALI** usealla eri siemenella (hylkayssilmukan vuoksi) | Ei ML-KEM-vastinetta - UUSI mittari |
| Hylkaysten maara / Sign | Tilastoitava usean ajon yli (rvv-dilithium:n oma kokemus: ~9 yritysta yhdessa tapauksessa) | Ei ML-KEM-vastinetta - UUSI mittari |
| LUT/FF/BRAM/DSP (ECP5) | `nextpnr-ecp5`-resurssiraportti | ML-KEM (KeyGen, taysi orkestraattori): ~9057 solua VAIN f1600:lle |
| Fmax | `nextpnr-ecp5 --timing-report` | ML-KEM (pqc_ntt_stage_banked, optimoitu): 30.40 MHz |
| Lapimenoaika (us/operaatio) | sykli-maara / Fmax | ML-KEM: 80.13 us/NTT (1-vaiheisella pipelinella) |

**HUOM Signin oma erityispiirre:** koska hylkayssilmukka voi toistua
vaihtelevan maaran kertoja, "syklit/Sign" EI ole yksi luku vaan
JAKAUMA - raportoitava AINA keskiarvo + min/max (tai mieluummin
mediaani + 95. persentiili) VAHINTAAN 20-30 eri siemenella/viestilla,
EI VAIN yhdella tapauksella (toisin kuin KeyGen/Verify, joilla yksi
mittaus riittaa koska ei ole satunnaisuutta sykliluvun laskennassa).

### 8.2 Hyvaksymiskriteerit (samat neljä kategoriaa kuin ML-KEM:ssa)

Jokaiselle tyopaketille (DILITHIUM-KEYGEN, -VERIFY, -SIGN) sovelletaan
TASMALLEEN samat neljä hyvaksymiskriteeria kuin ML-KEM:ssa:

1. **Algoritminen oikeellisuus** - golden-vertailu `dilithium-py`:ta
   vasten (EI omaa manuaalista referenssia, ks. osio 5), useilla
   testitapauksilla (mukaan lukien negatiivikontrollit: vaara viesti,
   turmeltu allekirjoitus - kuten rvv-dilithium:ssa jo tehtiin).
2. **Regressiotestit** - CI-integroitu, samalla run_*.sh + workflow-
   mallilla kuin ML-KEM:lla. Regressiotestin OMA toimivuus todistettava
   (esim. palauttamalla loydetty bugi tarkoituksella, kuten AUDIT_
   WORD_SEL-tapauksessa) ennen tyopaketin sulkemista.
3. **Synteesikelpoisuus** - Yosys/nextpnr-ecp5-synteesi lapaisty,
   DP16KD (jos BRAM-pohjaista muistia kaytetaan) tai vastaava
   resurssi vahvistettu oikeaksi maaraksi.
4. **Mitattu suorituskyky** - kaikki osion 8.1 mittarit raportoitu
   JOKAISELLE tyopaketille ENNEN sen sulkemista, EI vasta jalkikateen.

### 8.3 Miksi tama helpottaa koko TAU-kehyksen dokumentointia

Kun Dilithium-tyo raportoi TASMALLEEN samat mittarikategoriat kuin
ML-KEM (ks. taulukko 8.1), koko TAU-kehyksen (KeyGen+Encaps+Decaps+
DilithiumKeyGen+Verify+Sign) YHTEENVETOTAULUKKO voidaan koota
YHTENAISESTI ilman jalkikateista mittariyhdenmukaistamista - sama
rakenne joka jo osoittautui arvokkaaksi ML-KEM:n omassa M4-FPGA-
sarjassa (M4_TAU_FULL_PROTOCOL_MILESTONE.md:n oma vertailutaulukko).

## 9. Ei viela tehty / seuraava konkreettinen askel

Tama dokumentti on SUUNNITELMA, ei toteutusta. Seuraava konkreettinen
askel (kun tyo aloitetaan): **DK1 - 32-bittinen NTT-ydin** -
todennettava `dilithium-py`:n omaa `polynomials.py`-moduulia vasten
ENNEN mitaan orkestrointityota, samaan tapaan kuin ML-KEM:n oma NTT
todennettiin M1/M2-vaiheissa ennen K-PKE-tyota.
