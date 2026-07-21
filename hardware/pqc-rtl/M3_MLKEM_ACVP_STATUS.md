# M3-MLKEM-001: NIST ACVP -testivektorien todennus (ML-KEM / FIPS 203)

**Paivamaara:** 2026-07-21

## Tausta

Sama menetelma kuin ML-DSA-65:lle (`dilithium-rtl/NIST_ACVP_STATUS.md`):
RTL testataan NIST:n virallisia ACVP-KAT-vektoreita vastaan, ei vain
omaa `mlkem_golden.py`-referenssia vastaan.

Lahde: `usnistgov/ACVP-Server`, hakemisto
`gen-val/json-files/ML-KEM-{keyGen,encapDecap}-FIPS203/`.

RTL kohdistuu ML-KEM-512 (K=2, `pqc_mlkem_keygen_core.sv`:n oma
parametri).

## mlkem_golden.py vs. NIST (ML-KEM-512, tcId=1)

Tulos: ek tasmaa, dk tasmaa.

## RTL KeyGen vs. NIST ACVP keyGen-FIPS203 (ML-KEM-512, tcId=1)

Testattu `pqc_mlkem_keygen_core.sv`, olemassa olevan `tb/pqc_mlkem_
keygen_tb.sv`:n kautta, testivektori NIST-peraiseksi vaihdettuna.

Tulos: PASS, tcId=1, 8024 sykli.

**Merkitys taman yhden tuloksen omalla painoarvolla:** ML-KEM KeyGen
on deterministinen putki ilman haarautuvia polkuja. `mlkem_golden.py`
on jo aiemmin validoitu tuhannen siemenen omassa regressiossa (ks.
`m2-golden/mlkem_regression.py`) - NIST-vektori on samaa testia eri
syotteella, EI uusi polku. Tama poistaa "referenssi ja toteutus
molemmat vaarin samalla tavalla" -riskin taman yhden operaation
osalta, mutta EI todista mitaan mita `mlkem_golden.py`:n oma
regressio ei jo kattanut rakenteellisesti.

## Tunnetut rajoitukset / jatkotyo

1. Yksi KAT-vektori (tcId=1). Sama kritiikki joka koski Dilithiumin
   tcId=26-vaihetta koskee tata symmetrisesti: ohut mutta ankkuroitu.
   Kun JSON->txt-ekstraktio on kirjoitettu, lisatapausten ajaminen on
   mekaanista - vahintaan 3-5 per operaatio suositellaan.

2. **Encaps/Decaps ei viela testattu.** Tama on ainoa kohta jossa
   uutta polkua oikeasti testataan: NIST:n oma `encapDecap-FIPS203`
   sisaltaa tarkoituksella rikottuja siphertext-arvoja
   (`reason: "modify c"` tms.) ja odottaa etta implisiittinen
   hylkays (Fujisaki-Okamoto, `K_bar = J(z||c)`) tuottaa TASMALLEEN
   oikean arvon rikotulle syotteelle. Projektin omat, itse generoidut
   Decaps-hylkaystestit (`byte_corrupted`, `bit_corrupted`) EIVAT
   korvaa tata - NIST:n omat hylkaystapaukset ovat riippumattomia
   testivektoreita samalla tavalla kuin sigVer/sigGen olivat
   ML-DSA-puolella. Tama on seuraava askel, priorisoiden hylkays-
   polkuja triviaalien onnistumistapausten sijaan.

3. Vain ML-KEM-512 (K=2) - RTL ei tue muita parametrisarjoja.

## mlkem_golden.py vs. NIST Encaps (ML-KEM-512, tgId=1, tcId=1)

Matkalla loydetty ja korjattu oma skriptivirhe (EI golden-mallin
eika RTL:n virhe): `mlkem_encaps_internal` palauttaa `(K, c)`, mutta
ensimmainen testiskripti purki paluuarvot jarjestyksessa `(c, k)`.
Loytyi ennen RTL-vaihetta, koska referenssiketju vahvistetaan aina
ensin - sama virhe RTL-vertailussa olisi nayttanyt RTL-bugilta.

Korjattu ekstraktioskripti (`gen_mlkem_nist_encaps_vector.py`)
sisaltaa nyt itsetarkistuksen: puretut kentat verrataan ML-KEM-512:n
tunnettuihin tavupituuksiin (ek=800, c=768, K=32, m=32) ennen
kirjoitusta. Tama olisi napannut taman spesifisen virheen (K/c-vaihto,
32 vs. 768 tavua), vaikka EI eroa K:ta ja m:aa toisistaan (molemmat 32
tavua).

Tulos korjauksen jalkeen: c tasmaa, k tasmaa.

## RTL Encaps vs. NIST ACVP encapDecap-FIPS203 (ML-KEM-512, tgId=1, tcId=1)

Testattu `pqc_mlkem_encaps_top.sv` (olemassa olevan `fpga/tau/
pqc_mlkem_encaps_top_tb.sv`:n kautta, testivektori NIST-peraiseksi
vaihdettuna).

Tulos: PASS, tcId=1, 14410 sykli.

## Tunnetut rajoitukset / jatkotyo (paivitetty)

4. **Decaps ei viela testattu.** Ks. `M3-MLKEM-002-encaps-decaps-plan.md`
   etukateen kirjatulla ennusteella vaihekohtaisille sykleille.
5. Vain yksi Encaps-vektori (tcId=1) - lisaa voidaan lisata mekaanisesti
   samalla `gen_mlkem_nist_encaps_vector.py`-skriptilla eri tc_id-
   argumentilla.
