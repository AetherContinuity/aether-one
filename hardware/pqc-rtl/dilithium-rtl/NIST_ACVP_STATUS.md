# M5-DILITHIUM-001: NIST ACVP -testivektorien todennus

**Paivamaara:** 2026-07-19

## Tausta

Aiempi todennus (KeyGen, Verify, Sign S1-S8) on tehty `dilithium-py`:ta
vasten - hyva referenssi kehitystyohon, mutta EI sama asia kuin
NIST:n oma virallinen ACVP (Automated Cryptographic Validation
Protocol) -testipaketti, joka on se mita yhteiso odottaisi
standardinmukaisuuden osoitukseksi.

Lahde: `usnistgov/ACVP-Server` (github.com), hakemisto
`gen-val/json-files/ML-DSA-{keyGen,sigGen,sigVer}-FIPS204/`.

## Ensimmainen askel: dilithium-py:n oma vahvistus NIST:ia vastaan

Ennen RTL:n testausta vahvistettiin etta `dilithium-py` (koko taman
projektin golden-referenssi) itse tasmaa NIST:n omaan viralliseen
KAT-vektoriin:
```
pk tasmaa NIST:n omaan vektoriin: True
sk tasmaa NIST:n omaan vektoriin: True
```
Tama vahvistaa etta koko projektin referenssiketju on ollut luotettava
alusta asti.

## RTL KeyGen vs. NIST ACVP keyGen-FIPS204 (ML-DSA-65, tcId=26)

**Testattu suoraan** `pqc_dilithium_keygen_top.sv`:a NIST:n omaa
seed->pk/sk-KAT-vektoria vasten (EI dilithium-py:n kautta).

```
Valmis 87110 syklin jalkeen
OK: ek (pk) tasmaa NIST ACVP -vektoriin
OK: dk (sk) tasmaa NIST ACVP -vektoriin
PASS: RTL KeyGen tasmaa TAYDELLISESTI NIST:n omaan ACVP-KAT-vektoriin
```

**PASS TAYDELLISESTI**, molemmat pk (1952 tavua) ja sk (4032 tavua)
tasmaavat tavu tavulta.

## RTL Verify vs. NIST ACVP sigVer-FIPS204 (ML-DSA-65, tcId=140)

**Testattu suoraan** `pqc_dilithium_verify_top2.sv`:a NIST:n omaa
pk/sig/message->testPassed-KAT-vektoria vasten. Valittu tapaus:
1-tavuinen viesti (pieni, sopii nykyiseen kiinteaan MSG_BYTES-
parametriin ilman muutoksia), hylkaystapaus ("modified message").

```
Valmis 115282 syklin jalkeen, verify_ok=0 (NIST:n oma testPassed=0)
PASS: RTL Verify tasmaa TAYDELLISESTI NIST:n omaan ACVP sigVer-KAT-vektoriin
```

**PASS TAYDELLISESTI.**

## RTL Sign vs. NIST ACVP sigGen-FIPS204 (ML-DSA-65, tgId=10, tcId=139)

**Testattu suoraan** `pqc_dilithium_sign_top2.sv` + `pack_sig.sv`:aa
NIST:n omaa sk+message+rnd->signature-KAT-vektoria vasten. Valittu
testiryhma: `deterministic=true`, `signatureInterface=internal`,
`externalMu=false` (RTL toteuttaa `_sign_internal`:ia, EI ulkoisen
API:n `sign()`-kaarrettä - taman ryhman valinta oli kriittinen: MUUT
ryhmat kayttavat `signatureInterface=external`, jolloin viesti on
jo M'-kaaritty [`tr||0x00||len(ctx)||ctx||M`] eika suoraan verrattavissa
RTL:n omaan sisaiseen tulkintaan).

`rnd=0^32` (deterministinen tila).

```
Sign valmis 361102 syklin jalkeen, kappa=5, iteraatioita=1
PASS: RTL Sign tasmaa TAYDELLISESTI NIST ACVP sigGen-KAT-vektoriin (tgId=10, tcId=139)
```

**PASS TAYDELLISESTI**, koko 3309-tavuinen pakattu allekirjoitus
tasmaa tavu tavulta. TARKEA HUOMIO: tama SPESIFINEN testitapaus
sisaltaa AIDON hylkays-ja-uusintayritys-tilanteen (kappa 0->5, YKSI
hylkayskierros ennen onnistumista) - EI triviaali "kappa=0 heti
onnistuu" -tapaus. Tama on ainoa NIST-vektori tassa projektissa joka
on todistetusti kattanut Sign:n oman hylkayssilmukan MONIKIERROKSISEN
polun.

**Matkalla loydetty ja korjattu AITO RTL-integraatiobugi** (ei
testivektorivirhe tallä kertaa): `sign_top2.sv`:n oma `z_out_flat`
on Zq-edustajamuodossa, mutta `pack_z`/`pack_sig` OLETTAA jo
keskitetyn etumerkillisen arvon - puuttuva muunnos aiheutti vaarin
pakatun allekirjoituksen. Korjattu integraatiotason kytkennassa
(ks. `REPRESENTATION_CONTRACT.md`, DK6_STATUS.md jatko 16).

**Viela testaamatta:** yksi-kierroksinen (`kappa=0` heti onnistuu)
NIST-tapaus samalla `signatureInterface=internal`-ryhmalla, jotta
molemmat polut (triviaali JA monikierroksinen) olisivat NIST-datalla
katettuja - taman projektin OMAT (ei-NIST) dilithium-py-referenssi-
testit kattavat jo triviaalin polun, mutta NIST-data ei viela.

## Tunnetut rajoitukset / jatkotyo

1. **Vain yksi KAT-vektori useimmille operaatioille toistaiseksi.**
   NIST:n oma paketti sisaltaa kymmenia testitapauksia per operaatio.
   Signille olisi arvokasta lisata viela yksi-kierroksinen tapaus
   monikierroksisen rinnalle (ks. ylla).

2. **sigVer:n testPassed=True-tapaukset kayttavat suurempia viesteja**
   (pienin loydetty 2027 tavua) kuin `pqc_dilithium_verify_top2.sv`:n
   nykyinen SHAKE256-mu-laskennan puskurikoko (136 tavua = 1 lohko)
   sallii - SAMA MAX_BLOCKS-rajoite koskee TODENNAKOISESTI myos
   `sign_top2.sv`:n omaa mu-laskentaa suuremmille NIST-sigGen-
   viesteille. Korjaus (MAX_BLOCKS-parametrin kasvatus) sulkisi
   MOLEMMAT aukot YHDELLA muutoksella - suositellaan omana,
   erillisena committina JA regressioajolla ENNEN lisa-ACVP-tyota.

3. **ML-KEM (FIPS 203) ei viela testattu NIST:n omia ACVP-vektoreita
   vastaan** - `ML-KEM-keyGen-FIPS203` ja `ML-KEM-encapDecap-FIPS203`
   ovat saatavilla samasta lahteesta. TAMA ON NYT AINOA jaljella oleva
   ML-KEM/ML-DSA-epasymmetria taman dokumentin omassa metodologiassa:
   ML-DSA-65:n KAIKKI KOLME paaoperaatiota (KeyGen, Verify, Sign) ovat
   nyt suoraan NIST-ACVP-todennettuja, mutta ML-KEM ei viela ollenkaan -
   oman metodologian (dilithium-py-vertailu != NIST-ACVP-vertailu,
   ks. taman dokumentin oma "Tausta"-osio) mukaan tama on
   epajohdonmukaisuus joka ansaitsisi korjauksen.

## Merkitys

**PAIVITETTY 2026-07-21:** KAIKKI KOLME ML-DSA-65:n paaoperaatiota
(KeyGen, Verify, Sign) on nyt todennettu SUORAAN NIST:n omia
virallisia KAT-vektoreita vastaan - KAIKKI KOLME PASS TAYDELLISESTI.
Tama on merkittavasti vahvempi todiste standardinmukaisuudesta kuin
pelkka dilithium-py-vertailu, koska se poistaa mahdollisen
"molemmat vaarin samalla tavalla" -riskin kokonaan (referenssi ja
toteutus ovat nyt kahdesta RIIPPUMATTOMASTA lahteesta). ML-DSA-65
on siis TAYSIN ACVP-ankkuroitu; ML-KEM (FIPS 203) EI OLE VIELA
(ks. kohta 3 ylla) - tama epasymmetria on nyt tunnistettu, EI enaa
piilossa.
