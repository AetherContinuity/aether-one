# M3-MLKEM-001: NIST ACVP -testivektorien todennus (ML-KEM / FIPS 203)

**Paivamaara:** 2026-07-21

## Tausta

Sama metodologia kuin ML-DSA-65:lle (ks. `dilithium-rtl/NIST_ACVP_
STATUS.md`) - todennetaan RTL suoraan NIST:n virallisia ACVP-KAT-
vektoreita vasten, EI vain omaa `mlkem_golden.py`-referenssia vasten.
Tama korjaa aiemmin tunnistetun epasymmetrian: ML-DSA-65:n kaikki
kolme paaoperaatiota olivat jo NIST-ACVP-todennettuja, ML-KEM ei
ollenkaan.

Lahde: sama `usnistgov/ACVP-Server`, hakemisto
`gen-val/json-files/ML-KEM-{keyGen,encapDecap}-FIPS203/`.

RTL-toteutus kohdistuu **ML-KEM-512** (K=2), vahvistettu
`pqc_mlkem_keygen_core.sv`:n omasta `parameter int K = 2`.

## Ensimmainen askel: mlkem_golden.py:n oma vahvistus NIST:ia vastaan

```
tcId=1: ek tasmaa=True, dk tasmaa=True
```
PASS ensimmaisella yritetylla tcId:lla (ML-KEM-512-ryhman
ensimmainen testi).

## RTL KeyGen vs. NIST ACVP keyGen-FIPS203 (ML-KEM-512, tcId=1)

**Testattu suoraan** `pqc_mlkem_keygen_core.sv`:aa (olemassa olevan
`tb/pqc_mlkem_keygen_tb.sv`:n kautta, testivektori vaihdettu NIST-
peraiseksi) NIST:n omaa d+z->ek/dk-KAT-vektoria vasten.

```
OK ek (=ekPKE): tasmaa golden-malliin
OK dk (=dkPKE||ek||H(ek)||z): tasmaa golden-malliin
PASS: ML-KEM.KeyGen_internal(d,z) -> (ek,dk) tasmaa golden-malliin
```

**PASS TAYDELLISESTI ENSIMMAISELLA YRITYKSELLA**, ~8024 sykli
(80236000 ps @ 10ns/sykli).

## Tunnetut rajoitukset / jatkotyo

1. Vain yksi KAT-vektori (tcId=1) toistaiseksi - lisaa voidaan lisata
   samalla menetelmalla.
2. **Encaps/Decaps ei viela testattu NIST:n omia ACVP-vektoreita
   vastaan** (`ML-KEM-encapDecap-FIPS203`) - looginen seuraava askel,
   sisaltaa Fujisaki-Okamoto-muunnoksen implisiittisen hylkayksen
   (Decaps), joka on erityisen tarkeaa oikeellisuuden kannalta.
3. Vain ML-KEM-512 (K=2) todennettu - RTL EI tue muita parametri-
   sarjoja (K=3/4), joten tama on koko toteutuksen kattava tulos
   taman parametrin osalta.

## Merkitys

**ML-KEM:n KeyGen ON NYT NIST-ACVP-todennettu**, sulkien osan
aiemmin tunnistetusta ML-KEM/ML-DSA-epasymmetriasta. Encaps/Decaps
jaavat viela avoimiksi.
