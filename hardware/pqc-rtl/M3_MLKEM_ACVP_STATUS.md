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

Tulos: PASS, tcId=1 (14410 sykli), tcId=2 (14410 sykli), tcId=3 (14426 sykli). 3/3.

## Tunnetut rajoitukset / jatkotyo (paivitetty)

4. **Decaps ei viela testattu.** Ks. `M3-MLKEM-002-encaps-decaps-plan.md`
   etukateen kirjatulla ennusteella vaihekohtaisille sykleille.
5. Vain yksi Encaps-vektori (tcId=1) - lisaa voidaan lisata mekaanisesti
   samalla `gen_mlkem_nist_encaps_vector.py`-skriptilla eri tc_id-
   argumentilla.

## RTL Decaps vs. NIST ACVP encapDecap-FIPS203 (ML-KEM-512, tgId=4, 5 tapausta)

Testattu `pqc_mlkem_decaps_top.sv` (Phase A: `decaps_a_core`, Phase B:
`decaps_b1_core`) NIST:n omia dk+c->K-KAT-vektoreita vasten.

**Luokittelu (valid/rejection) tehty RIIPPUMATTOMASTI** Pythonin
omalla `c'==c`-laskennalla `gen_mlkem_nist_decaps_vectors.py`:ssa,
EI luotettu pelkkaan JSON:n `reason`-kenttaan - riippumaton laskenta
tasmasi `reason`-kenttaan kaikissa 10:ssa tarkistetussa tapauksessa.

Valitut tapaukset: tcId 76,79 (valid decapsulation), tcId 77,78,80
(modified ciphertext / implisiittinen hylkays).

Tulos: kaikki 5 tapausta K tasmaa NIST-vektoriin.

### Vaihekohtaiset syklit, 5 eri avainta (NIST:n oma data)

| tcId | luokka | Phase A (sykli) | Phase B (sykli) | Yhteensa |
|---|---|---|---|---|
| 76 | valid | 7666 | 14195 | 21863 |
| 79 | valid | 7666 | 14188 | 21856 |
| 77 | rejection | 7666 | 14183 | 21851 |
| 78 | rejection | 7666 | 14195 | 21863 |
| 80 | rejection | 7666 | 14186 | 21854 |

**Havainto:** Phase A on TASMALLEEN sama (7666) kaikissa viidessa
tapauksessa. Phase B vaihtelee ~12 syklin sisalla (14183-14195), MUTTA
tama vaihtelu EI korreloi valid/rejection-luokan kanssa (esim. tcId=78
[rejection] ja tcId=76 [valid] ovat MOLEMMAT 14195 - identtiset;
tcId=77 [rejection] on PIENIN kaikista). **Syy loydetty:** NAMA 5
NIST-testitapausta kayttavat KAIKKI ERI avainta (eri dk/rho jokaiselle
tcId:lle) - Phase B:n oma vaihtelu selittyy TODENNAKOISESTI `ExpandA`:n
(SampleNTT-hylkaysnaytteistys, rho-riippuvainen) avain-kohtaisella
iteraatiomaaralla, EI valid/rejection-erolla.

### ExpandA:n oma, julkiseen syotteeseen sidottu vaihtelu - oma rivinsa, ei sivuhuomio

**Tama ~12 syklin vaihtelu ON ajoitusvaihtelua JULKISESTA syotteesta,
EI salaisesta.** `rho` on `ek`:n (julkisen avaimen) osa - hyokkaaja
TIETAA rho:n jo ilman mitaan sivukanavaa, koska se on osa julkista
avainta jonka hyokkaaja saa suoraan. Vakioaikakonvention (constant-
time cryptography) mukaan JULKISESTA syotteesta riippuva ajoitus-
vaihtelu ON HYVAKSYTTAVAA - vain SALAISESTA datasta (kuten `z`,
`m_prime`, tai vertailun tulos) riippuva ajoitusvaihtelu olisi
ongelma.

**Tama TAYTYY sanoa AUKI, koska ilman tata joku lukee raakadatan
(taulukko ylla), nakee syklierot ERI tcId:iden valilla, ja paattelee
etta 'syklitasolla vakioaikainen' -vaite on VAARIN - vaikka se EI OLE,
koska havaittu vaihtelu on JULKISEN, ei salaisen, syotteen aiheuttamaa.**

### Puhdas saman-avaimen vertailu (sekavuustekija poistettu)

Koska NIST:n oma data EI tarjoa saman avaimen useampaa ciphertext-
tapausta tassa testiryhmassa, rakennettiin YKSI lisavertailu: tcId=76:n
OMA avain (dk) + tcId=76:n oma validi ciphertext SEKA siita johdettu,
yhdella tavulla korruptoitu ciphertext (SAMA avain molemmissa,
riippumattomasti Pythonilla luokiteltu ja K-arvo vahvistettu).

**TARKEA EROTTELU EVIDENSSILAJIEN VALILLA (ei saa hukkua yhteen-
vedossa):** taman kokeen rooli ON ERI kuin 5 NIST-vektorin oma rooli.

- **5/5 NIST-vektoria** = KONFORMANSSIEVIDENSSI (RTL tuottaa oikean
  K:n NIST:n omalle, riippumattomasti luokitellulle datalle).
- **Saman-avaimen koe** = ITSE GENEROITU, KONTROLLOITU KOE
  AJOITUSMITTAUKSEEN, EI konformanssitodiste. Tama ON tasan se
  "itse generoitu hylkaystesti" -kategoria joka rajattiin ACVP-
  ankkuroinnin ULKOPUOLELLE aiemmin taman dokumentin omassa
  historiassa (ks. jatko: "projektin omat hylkaystestit EIVAT korvaa
  NIST:n riippumattomia vektoreita") - mutta TASSA se on kaytetty
  OIKEIN: kontrolloituna kokeena ajoituskysymykselle, EI
  standardinmukaisuusvaitteena. Konformanssi tulee YKSINOMAAN 5/5
  NIST-vektorista; ajoitusvaite tulee YKSINOMAAN kontrollikokeesta.
  Naita EI pida sekoittaa.

| Tapaus | luokka | Phase A | Phase B | Yhteensa |
|---|---|---|---|---|
| tcId=76:n oma c | valid | 7666 | 14195 | 21863 |
| tcId=76:n dk + korruptoitu c | rejection | 7666 | 14195 | 21863 |

TASAN SAMAT syklimaarat molemmilla poluilla, kaikissa kolmessa
mittarissa (Phase A, Phase B, kokonaissykli), kun avain pidetaan
vakiona.

**Rajaus koekattavuudelle:** taman kontrollikokeen oma korruptio testasi
YHDEN tavun muutosta (yksi hylkaysreitti). Koska tulos oli TASAN SAMA
syklimaara (ei "pieni ero"), LAAJEMPI korruptiovariaatio (useampi
tavu, eri sijainnit) EI TODENNAKOISESTI toisi lisatietoa SYKLITASOLLA -
jos yksi bittimuutos jo tuottaa saman syklimaaran kuin ei-mikaan-
muutos, muut bittimuutokset todennakoisesti tekevat samoin (FSM:n oma
rakenne ei haaraudu c:n sisallon perusteella, vain sen JALKEEN
lasketun vertailun TULOKSEN perusteella, joka on jo osoitettu
syklivakioksi mux:ina). Taman kontrollikokeen NYKYINEN laajuus (1
tavu) RIITTAA taman kysymyksen kannalta - lisakorruptiovariaatiot
EIVAT ole priorisoitu jatkotyoksi.

### Johtopaatos (tarkka muotoilu, ks. M3-MLKEM-002-encaps-decaps-plan.md)

**Decaps on SYKLITASOLLA vakioaikainen SALAISEN DATAN suhteen; julkis-
riippuvainen vaihtelu ExpandA:ssa on dokumentoitu ja vakioaikakonvention
mukainen.** Tama tarkka muotoilu (KAKSI ehtoa: syklitaso + salainen
data) ON PAKOLLINEN taman tuloksen esittamisessa - kumpikin sana
("syklitasolla" JA "salaisen datan suhteen") on tarpeen, EI vain jompi
kumpi.

Jaljelle jaava vuotopinta (kytkentaaktiivisuus vertailu-/mux-logiikassa,
SAMALLA syklilla mutta datariippuvasti) ON maaritelmallisesti
`toggle-count-proxy`-tyokalun oma kohde, ei mitattu tassa.

Ennuste (M3-MLKEM-002-encaps-decaps-plan.md, kirjattu ennen mittausta,
molemmilla ehdoilla: vakioaikainen vertailu JA J-hash ehdotta
laskettu) TOTEUTUI TASAN puhtaassa saman-avaimen vertailussa.

### Sivutuote: z:n kasittelyn ensimmainen NIST-ankkurointi

Rejection-tapaukset (77,78,80) todensivat ENSIMMAISTA KERTAA `z`:n
(dk:n neljas osa) kasittelyn koko ketjun - `dk`-purku -> `z`:n sijainti
-> `J(z||c)`-syote (800 tavua) - NIST:n omaa dataa vasten. Valid-polku
EI KOSKAAN kayta z:aa (K_bar lasketaan mutta hylataan valinnassa), joten
tama on Decapsin AINOA osa jota mikaan aiempi testi (Encaps, KeyGen)
ei ole ankkuroinut.
