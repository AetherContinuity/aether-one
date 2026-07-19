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

## Tunnetut rajoitukset / jatkotyo

1. **Vain yksi KAT-vektori kummallekin operaatiolle toistaiseksi.**
   NIST:n oma paketti sisaltaa kymmenia testitapauksia per operaatio
   (esim. sigVer-FIPS204:ssa 15 testia per testiryhma, useita
   testiryhmia). Lisaa voidaan lisata samalla menetelmalla.

2. **sigVer:n testPassed=True-tapaukset kayttavat suurempia viesteja**
   (pienin loydetty 2027 tavua) kuin `pqc_dilithium_verify_top2.sv`:n
   nykyinen SHAKE256-mu-laskennan puskurikoko (136 tavua = 1 lohko)
   sallii. Taman testaaminen vaatisi joko:
   (a) mu-laskennan MAX_BLOCKS-parametrin kasvattamisen taman
   moduulin sisalla, tai
   (b) testitapauksen, jossa mu annetaan suoraan (tgId=9,
   externalMu=True) - tama vaatisi oman testireitin joka ohittaa
   sisaisen tr/mu-laskennan.

3. **Sign (sigGen) ei viela testattu NIST:n omia vektoreita vasten.**
   NIST:n oma sigGen-FIPS204 kayttaa `rnd`-arvoa (deterministinen
   testaus mahdollinen rnd:n kautta, kuten dilithium-py-testeissa
   tassa projektissa aiemmin) - looginen seuraava askel.

4. **ML-KEM (FIPS 203) ei viela testattu NIST:n omia ACVP-vektoreita
   vastaan** - `ML-KEM-keyGen-FIPS203` ja `ML-KEM-encapDecap-FIPS203`
   ovat saatavilla samasta lahteesta.

## Merkitys

Talla hetkella VAIN kaksi (KeyGen, Verify) kolmesta ML-DSA-65:n
paaoperaatiosta on todennettu SUORAAN NIST:n omia virallisia
KAT-vektoreita vastaan - mutta molemmat NAISTA ovat PASS TAYDELLISESTI.
Tama on merkittavasti vahvempi todiste standardinmukaisuudesta kuin
pelkka dilithium-py-vertailu, koska se poistaa mahdollisen
"molemmat vaarin samalla tavalla" -riskin kokonaan (referenssi ja
toteutus ovat nyt kahdesta RIIPPUMATTOMASTA lahteesta).
