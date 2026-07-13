# M3 Issue #15 — SampleNTT: golden-malli (Vaihe 1/3)

**Päivämäärä:** 2026-07-12
**Tila:** Golden-malli valmis ja kaksinkertaisesti ulkoisesti
ankkuroitu. EI RTL:aa viela.

## 1. Tarkistettu FIPS 203:n lopullisesta tekstista (ei luonnoksesta)

Algoritmi 7 (SampleNTT) ja **Liite B (SampleNTT Loop Bounds)**
haettu ja tarkistettu suoraan nvlpubs.nist.gov/nistpubs/fips/nist.fips.203.pdf:sta.

Liite B:n keskeinen sisalto: SampleNTT:n while-silmukkaa EI SAA
rajoittaa jos se on vain jotenkin valtettavissa. Jos toteutus KUITENKIN
rajaa silmukan, rajaa EI SAA asettaa alle **280 iteraation**
(todennakoisyys ylittaa taman: 2^-261). Koska jokainen iteraatio
kuluttaa 3 tavua XOF-ulostuloa, tama tarkoittaa **vahintaan 840 tavua**.

## 2. Tarkea rajaus - kaksi eri asiaa (kayttajan oma huomio)

**Issue #14:n oma "ML_KEM_XOF_style"-testi (504 tavua) oli XOF-
PRIMITIIVIN oma toiminnallinen testi** - se osoitti etta SHAKE128
tuottaa oikean, pidemman ulostulon oikein (padding, absorbointi,
useampi squeeze-kierros). **Se EI ollut eika sen tarvinnut olla
SampleNTT-ALGORITMIN normatiivinen toteutustesti.** 504 tavua (168
iteraatiota) EI tayta Liite B:n 280 iteraation minimivaatimusta, jos
SampleNTT joskus toteutettaisiin RAJATULLA silmukalla.

Tama moduuli (samplentt_golden.py) kayttaa siksi ERI, suurempaa
oletuspuskuria (DEFAULT_XOF_BYTES=1008 tavua = 336 iteraatiota,
reilusti yli 840:n minimin) - eri kayttotarkoitus, eri vaatimus,
ei ristiriita Issue #14:n kanssa.

## 3. Kolmivaiheinen golden-mallin rakennus (kayttajan oma ehdotus)

1. **Puhdas hylkaysnaytteenotto** (`samplentt_golden.py`): Algoritmi 7
   rivi riviltä, xof_bytes>=840 (kaytannossa 1008 oletuksena).
2. **Instrumentointi**: `sample_ntt(..., instrument=True)` palauttaa
   hyvaksyttyjen/hylattyjen maaran ja kulutettujen XOF-tavujen maaran
   - ei vain lopullista 256 kertoimen taulukkoa.
3. **Jaadytetty referenssi** (`gen_samplentt_frozen_reference.py` ->
   `vectors/samplentt_frozen_reference.json`, committoitu sellaisenaan):
   viisi kiinteaa testitapausta.

## 4. Genuiini "unlucky"-reunatapaus - riippumaton ulkoinen ankkurointi

Haettu C2SP/CCTV:n (github.com/C2SP/CCTV) `unluckysample.go`:sta -
tunnetut, julkaistut 32-tavuiset siemenet jotka tuottavat
POIKKEUKSELLISEN MONTA hylkaysta SampleNTT:n rho=SHA3-512(d)[:32],
j=0, i=0 -tapauksessa (K-PKE.KeyGenin ensimmainen A[0][0]-kutsu).

**Taydellinen tasmays kolmella tunnetulla siemenella:**

| Siemen (d, lyhennetty) | C2SP:n oma "samples"-laskuri | Oma tulos |
|---|---|---|
| 518aa157... | 380 | 380 (TASMAA) |
| 851cf0ee... | 381 | 381 (TASMAA) |
| 8c7238e1... | 384 | 384 (TASMAA) |

Tama on VAHVA, riippumaton ulkoinen vahvistus SEKA oman SHA3-512-
toteutuksen (rho=SHA3-512(d)[:32] taytyy tasmata heidan omaansa,
jotta samat XOF-tavut generoituisivat) ETTA oman SampleNTT-toteutuksen
(rejection-sampling-logiikan taytyy tasmata tarkalleen) osalta -
samanaikaisesti, koska molemmat ovat tassa testissa mukana.

Nama kolme "unlucky"-tapausta lisatty jaadytettyyn referenssiin
omana, ERIKSEEN merkittyna ryhmanaan (source-kentta viittaa
alkuperaan) - taydentavat kaksi alkuperaista kiinteaa (ei-satunnaista)
perustapausta.

## 5. Ei viela tehty

Ei RTL:aa. Seuraava askel: RTL-toteutus (iteratiivinen, sama
periaate kuin Keccakissa - yksi 3-tavun XOF-squeeze + tarkistus per
sykli tai muutama sykli), verrattuna talla golden-mallilla juuri
tuotettuun jaadytettyyn referenssiin. Jaadytetty referenssi sisaltaa
sekä lopullisen 256 kertoimen taulukon ETTA instrumentoinnin
(hyvaksytyt/hylatyt/kulutetut tavut) - RTL voidaan siis verrata
molempiin, ei vain lopputulokseen (sama periaate kuin Keccakin
kierrostilat, Issue #10).
