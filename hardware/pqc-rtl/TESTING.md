# Testien taksonomia (aether-one / hardware/pqc-rtl)

Tama dokumentti maarittaa kolmitasoisen testiluokittelun, joka otettiin
kayttoon M5-DILITHIUM-001-tyon myohaisessa vaiheessa (2026-07-19), kun
projekti siirtyi aktiivisesta algoritmikehityksesta vakaampaan yllapito-
ja regressiovaiheeseen. Luokittelu selkeyttaa, MITEN ja MILLOIN kukin
testi ajetaan.

## Kolme tasoa

### 1. Unit
Yksittainen moduuli, minimaaliset riippuvuudet (ei jaeta yhteista raskasta
tiedostolistaa muiden moduulien kanssa). Sekunneissa valmis. **Ajetaan
joka pushilla.**

Esimerkkeja: Barrett-mulmod, Decompose, MakeHint, UseHint, pack_z,
pack_h, pack_w, SampleInBall, yksittaiset NTT-butterfly-testit.

Nimeamiskaytanto uusille skripteille: `run_unit_<aihe>.sh`.

### 2. Component
Kokonainen vaihe/rakennuspalikka, joka yhdistaa useita Unit-tason
moduuleja yhdeksi toiminnalliseksi kokonaisuudeksi (esim. Sign-algoritmin
yksi S-vaihe, tai KeyGen/Verify:n yksi laskentalohko). Sekunneista
pariin minuuttiin. **Ajetaan joka pushilla**, paitsi jos yksittainen
testi on poikkeuksellisen raskas (ks. alla).

Esimerkkeja: ExpandA, ExpandS, ExpandMask (S1/S2), Challenge-generointi
(S4), keygen_core, verify_core, pack_sig.

Nimeamiskaytanto uusille skripteille: `run_component_<aihe>.sh`.

### 3. Integration
Taysi RTL-orkestrointi (KeyGen/Sign/Verify top-level) tai useamman
paaoperaation ketjutus. Kymmenista tuhansista satoihin tuhansiin
sykleihin - VOI vieda kymmenia minuutteja. **Ajetaan VAIN
julkaisutageilla (v*) tai kasin laukaistuna** (workflow_dispatch),
EI joka pushilla - ks. `.github/workflows/dilithium-heavy-integration.yml`.

Poikkeus: yksittaisen paaoperaation OMA taysi orkestrointitesti (esim.
Verify-regressio, 4 testia ~115000 sykli kukin) on toistaiseksi PIDETTY
paaworkflow'ssa, koska se on jo lukittu regressiosuoja eika sen
poistaminen toisi lisaarvoa - mutta UUSIA vastaavia raskaita testeja EI
ENAA lisata paaworkflow'hun ilman erityista syyta.

Esimerkkeja: pqc_dilithium_keygen_top (KeyGen), pqc_dilithium_verify_top2
(Verify, 4 varianttia), pqc_dilithium_sign_top2 (Sign, positiivinen +
monisiemeninen), full_chain_tb (KeyGen->Sign->Verify koko ketju, EI VIELA
vahvistettu - ks. DK6_STATUS.md).

Nimeamiskaytanto uusille skripteille: `run_integration_<aihe>.sh`.

## Miksi tama jako on tarkea

Yhteinen, kaiken kattava tiedostolista (esim. `dilithium_common_files.sh`)
on OIKEA ratkaisu Integration-tason testeille, koska se varmistaa
yhdenmukaisuuden koko ketjun yli. MUTTA sama lista sisaltaa raskaita
moduuleja (esim. `sign_hint_core`, 1536 rinnakkaista instanssia), jotka
hidastavat elaboraatiota MYOS silloin kun testataan vain yhta pientaa
moduulia. Siksi Unit- ja Component-tason skriptit kayttavat OMIA,
minimaalisia tiedostolistojaan suoraan `iverilog`-kutsussa, EIVATKA
yhteista `compile_dilithium()`-funktiota.

## Nykyinen kartoitus (2026-07-19)

### Dilithium (M5-DILITHIUM-001)

| Skripti | Taso | Ajetaan |
|---|---|---|
| `run_unit_dilithium_sign_primitives.sh` | Unit | joka push |
| `run_component_dilithium_sign_stages.sh` | Component | joka push |
| `run_integration_dilithium_verify_positive.sh` | Integration (poikkeus, lukittu) | joka push |
| `run_integration_dilithium_verify_negative_sig.sh` | Integration (poikkeus, lukittu) | joka push |
| `run_integration_dilithium_verify_negative_pk.sh` | Integration (poikkeus, lukittu) | joka push |
| `run_integration_dilithium_verify_multiseed.sh` | Integration (poikkeus, lukittu) | joka push |
| `run_integration_dilithium_sign_positive.sh` | Integration | tagi/kasin |
| `run_integration_dilithium_sign_multiseed.sh` | Integration | tagi/kasin |

Yksittaiset `pqc_dilithium_*_tb.sv`-tiedostot (dilithium-rtl/-hakemistossa),
joita ei viela ole koottu omiksi run-skripteikseen, ovat kaikki
UNIT- tai COMPONENT-tasoisia ja ajettavissa kasin tarvittaessa samalla
minimaalisen-tiedostolistan periaatteella.

### ML-KEM (M1-M4) - SAILYTETTY ENNALLAAN, EI NIMETTY UUDELLEEN

M1-M4-sarjan skriptit (`run_m1_*.sh` ... `run_m4_*.sh`) ovat vanhempaa,
jo vakiintunutta ja CI:ssa laajasti viitattua nimeamiskaytantoa. Naita
EI nimetty uudelleen taman taksonomian mukaisiksi, koska uudelleen-
nimeaminen olisi ollut tarpeettoman riskialtis operaatio suhteessa
saatuun hyotyyn (CI-workflow'ssa on kymmenia viittauksia naihin).
Karkea vastaavuus:
- `run_m3_*` (yksittaiset SHA3/Keccak/NTT/CBD-moduulit) ~ Unit
- `run_m3_kpke_*`, `run_m3_mlkem_*` (kokonaiset K-PKE/ML-KEM-vaiheet) ~ Component
- `run_m4_tau_*` (TAU/Wishbone-integraatio) ~ Integration (jo lukittu, kevyempi
  skaala kuin Dilithium Sign, joten pidetty paaworkflow'ssa)

Uusia ML-KEM-testeja lisattaessa suositellaan JATKOSSA noudattamaan
tata samaa kolmitasoista nimeamiskaytantoa.
