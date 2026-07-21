# SYNTH-001: Barrett multiplier pipeline exploration

**Status:** Open
**Created:** 2026-07-21
**Priority:** Performance optimization candidate (post-functional-
verification phase)
**Related:** `SYNTHESIS_REPORT.md`, `pqc_dilithium_barrett_mulmod.sv`,
`SYNTH-TEMPLATE.md`

## Vakiorakenne (ks. SYNTH-TEMPLATE.md)

| Kohta | Sisalto |
|---|---|
| **Tavoite** | Vahentaa `pqc_dilithium_barrett_mulmod.sv`:n oma looginen kriittinen polku (107 tasoa) jakamalla nykyinen taysin kombinatorinen toteutus 2-3 rekisteroituun pipeline-vaiheeseen. YKSI moduuli, EI koko NTT- tai ML-DSA-putki kerralla. |
| **Lahtotilanne** (MITATTU, ei arvioitu - 2026-07-21) | `ltp`: **107 logiikkatasoa**. Solumaara (`synth`+`stat`): **6517 solua**. FF-maara: **0** (taysin kombinatorinen). Nailla arvoilla EI viela ole tehty mitaan muutosta - tama on baseline. |
| **Muutos** | Jaetaan Barrett-reduktion nykyinen yksisyklinen laskuketju (kertolasku -> Barrett-vakiokertolasku -> vahennys/korjaus) 2 TAI 3 rekisteroituun valivaiheeseen. Tarkka jakokohta paatetaan toteutusvaiheessa `ltp`:n omaa polkuerittelya kayttaen (etsitaan luonnollinen "puoliväli"-kohta pisimmalla polulla). |
| **Mittarit** | (1) `ltp`-logiikkatasot JOKAISELLE pipeline-vaiheelle erikseen (tavoite: selvasti alle 107/vaihe). (2) Solu-/FF-maara (`synth`+`stat`) - FF:n odotetaan kasvavan (uudet pipeline-rekisterit), solumaaran pysyvan suunnilleen ennallaan. (3) Sykliverkutus koko NTT-ytimeen (`pqc_dilithium_ntt_core.sv`:n oma taysi 256-kertoiminen muunnos, verrattuna tunnettuun baseline-arvoon ~3584-4095 sykli/NTT). (4) Fmax - VASTA kun P&R-resursseja on kaytettavissa (EI pakollinen hyvaksymiskriteeri tassa vaiheessa, ks. alla). |
| **Hyvaksymiskriteeri** | KAIKKI seuraavista: (a) `ltp` per pipeline-vaihe on selvasti pienempi kuin 107 (tavoite: <60 tasoa/vaihe); (b) KAIKKI olemassa olevat Barrett-mulmod:in JA NTT-ytimen Unit-/Component-tason testit (`TESTING.md`-taksonomia) pysyvat vihreina muuttamattomina; (c) sykliverkutus koko NTT-muunnokselle on kohtuullinen suhteessa saatuun `ltp`-parannukseen (ei kiinteaa kynnysarvoa etukateen - arvioidaan tapauskohtaisesti kun molemmat luvut ovat kaytettavissa). |

## Tausta

Yosys `ltp` (longest topological path) -analyysi loysi **107
logiikkatasoa** `pqc_dilithium_barrett_mulmod.sv`:n lapi - taman
moduulin Barrett-modulokertolasku, jota kaytetaan satoja kertoja
per taysi NTT-muunnos (forward JA inverse). Tama on syvin loydetty
toistuva kombinatorinen lohko koko M5-DILITHIUM-001-koodikannassa.

Taydellinen paikoitus+reititys-pohjainen Fmax-mittaus (`nextpnr-ecp5`)
EI konvergoinut kaytettavissa olevalla ajalla/resursseilla tassa
kehitysymparistossa (ks. `SYNTHESIS_REPORT.md`), joten absoluuttinen
Fmax pysyy viela mittaamattomana. `ltp`:n oma logiikkatasomaara ON
KUITENKIN vahva, tyokaluriippumaton signaali siita etta tama
NIMENOMAINEN lohko on merkittava kriittisen polun ehdokas, ja etta
sen pipelinointi on hyvin kohdennettu optimointikohde - riippumatta
siita mika lopullinen mitattu Fmax osoittautuu olevan.

## Kokeilumatriisi

| Variantti | Kuvaus | Kerattavat mittarit |
|---|---|---|
| **Baseline** | Nykyinen toteutus (0-vaiheinen, taysin kombinatorinen) | `ltp` (jo mitattu: 107), solumaara (jo mitattu: 6517), FF-maara (jo mitattu: 0) |
| **2-vaiheinen pipeline** | Kertolasku ja Barrett-reduktiovaihe jaettu yhdella rekisterirajalla | `ltp` per vaihe, solumaara, FF-maara, lisatyt syklit per NTT-butterfly-kutsu |
| **3-vaiheinen pipeline** | Pidemmalle jaettu (esim. kertolasku / osittainen reduktio / lopullinen korjaus) | Samat kuin ylla |

## Miksi tama on hyva seuraava kohde

- **Kapea, yhden moduulin muutos** - huomattavasti hallittavampi kuin
  yrittaa optimoida koko ML-DSA-putkea kerralla.
- Koska Barrett-kertolaskua kaytetaan **satoja kertoja** per NTT-
  muunnos, mika tahansa viivelyhennys taalla KERTAUTUU koko Sign-/
  Verify-/KeyGen-putkeen (kaikki kolme kayttavat NTT:ta laajasti).
- Olemassa oleva testi-infrastruktuuri (Unit-tason `barrett_mulmod`-
  synteesi/simulointi, Component-tason NTT-testit) tarjoaa jo
  NOPEAN regressiosuojan tallle muutokselle - EI uutta raskasta
  integraatiotestausta pitaisi tarvita toiminnallisen oikeellisuuden
  todentamiseksi, vain olemassa olevien ajaminen uudelleen.

## Rajaukset (EI kuulu tahan tehtavaan)

- Taydellinen paasta-paahan-Fmax-mittaus (jumissa P&R-konvergenssin
  takia tassa ymparistossa - seurataan erikseen, EI esta taman
  tutkimuksen aloittamista).
- ECP5 BRAM-kartoitustutkimus (aiemmin tunnettu avoin kysymys ML-KEM-
  tyosta, `SYNTHESIS_NOTE.md` - ei liity Barrett-pipelinointiin).
- `sign_hint_core`/`verify_core`:n oma arkkitehtuuritason
  rinnakkaisuusmuutos (1536-instanssinen Decompose/MakeHint-rakenne) -
  tama on erillinen, suurempi arkkitehtuurikysymys joka on jo
  merkitty `SYNTHESIS_REPORT.md`:n omiin suosituksiin, ei osa taman
  tehtavan kapeaa rajausta.
