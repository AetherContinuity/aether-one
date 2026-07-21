# SYNTH-001: Barrett multiplier pipeline exploration

**Status:** 2-stage variant IMPLEMENTED AND MEASURED (2026-07-21).
3-stage variant not yet attempted (see "Next step" below).
**Created:** 2026-07-21
**Priority:** Performance optimization candidate (post-functional-
verification phase)
**Related:** `SYNTHESIS_REPORT.md`, `pqc_dilithium_barrett_mulmod.sv`,
`pqc_dilithium_barrett_mulmod_pipe2.sv`, `SYNTH-TEMPLATE.md`

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

## TULOKSET: 2-vaiheinen variantti (2026-07-21, MITATTU)

**Toteutus:** `pqc_dilithium_barrett_mulmod_pipe2.sv` - jako kohdassa
"osamaaran arvio valmis" (VAIHE 1: `product=a*b`, `q_est=(product*M)>>K`;
VAIHE 2: `q_est_times_q=q_est*Q`, `r_wide=product-q_est_times_q`,
ehdollinen loppuvahennys). Rekisteroidaan seka `product` etta `q_est`
VAIHE 1:n ja VAIHE 2:n valiin, seka lopullinen tulos omaan ulostulo-
rekisteriinsa (kiintea 2 syklin latenssi, EI FSM-kasittelya - "syota
sisaan, odota 2 syklia, lue ulos").

**Toiminnallinen oikeellisuus (Unit-taso):** rakennettiin dedikoitu
testipenkki (`barrett_pipe2_tb.sv`) joka vertaa pipelinoitua
tulosta alkuperaiseen, taysin kombinatoriseen versioon 2 syklin
viiveella. **PASS TAYDELLISESTI 100 000/100 000 satunnaisella
testiparilla.** (Ensimmainen testiyritys, joka striimasi arvoja
jatkuvasti ilman riittavaa "asetu"-viivetta kombinatorisen referenssin
ja pipelinoidun tuloksen valilla, antoi vaarin noin 50% "virhepositii-
visia" - tama korjattiin yksinkertaisemmalla syota->odota-2-syklia->
tarkista-menetelmalla, JOKA PALJASTI ETTA ALKUPERAINEN "epaonnistuminen"
OLI TESTIPENKIN OMA ajoitusongelma, EI RTL-virhe - SAMA "tarkista oma
testimenetelma ensin" -periaate joka on toistunut lapi taman projektin.)

**Mittaustulokset (Yosys `synth`+`stat`+`ltp`, geneerinen synteesi):**

| Mittari | Baseline (0-vaihetta) | 2-vaiheinen pipeline | Muutos |
|---|---|---|---|
| `ltp` (kriittinen vaihe) | 107 tasoa | **68 tasoa** (Vaihe 1) / 41 tasoa (Vaihe 2) | **-36%** kriittisessa vaiheessa |
| Solumaara | 6 517 | 6 685 | +168 (+2.6%) |
| FF-maara | 0 | **93** (46+24+23, tasmaa tarkalleen `product_reg`+`q_est_reg`+`result_reg`:n omiin leveyksiin) | +93 |
| Latenssi | 0 sykli (kombinatorinen) | 2 sykli | +2 sykli/kutsu |

**Vaiheiden epatasapaino:** Vaihe 1 (68 tasoa: kaksi perakkaista
leveaa kertolaskua) on selvasti raskaampi kuin Vaihe 2 (41 tasoa: yksi
kertolasku + vahennys + vertailu). Tama viittaa siihen etta 2-vaiheinen
jako TASSA KOHDASSA EI OLE TAYSIN TASAPAINOSSA - 3-vaiheinen jako
(erottaen VAIHE 1:n omat kaksi kertolaskua omiksi vaiheikseen) voisi
paasta lahemmas alkuperaista <60 tasoa/vaihe -tavoitetta molemmille
vaiheille.

**Hyvaksymiskriteerin tarkistus:**
- (a) `ltp` per vaihe selvasti alle 107: ✅ TOTEUTUI (68/41 vs. 107),
  mutta EI aivan saavuttanut oman <60-tason tavoitetta molemmille
  vaiheille (Vaihe 1 jai 68:aan).
- (b) Olemassa olevat testit pysyvat vihreina: ✅ Alkuperainen
  `pqc_dilithium_barrett_mulmod.sv` EI MUUTETTU (pipe2 on UUSI,
  RINNAKKAINEN moduuli) - kaikki olemassa olevat testit koskematta.
  UUSI oma Unit-tason testi (100000/100000) PASS.
- (c) Sykliverkutus koko NTT-ytimeen: EI VIELA MITATTU - taman
  pipelinoidun Barrett-version INTEGROINTI `pqc_dilithium_ntt_core.sv`:n
  omaan FSM:aan (joka nykyaan olettaa Barrett-kutsun olevan
  KOMBINATORINEN, 0 syklin latenssi) VAATISI FSM:n omaa muutosta -
  TAMA ON RAJATTU TAMAN KOKEILUN ULKOPUOLELLE (ks. "Seuraava askel"
  alla) - SYNTH-001:n TAMA VAIHE todistaa VAIN etta pipelinoitu
  Barrett-moduuli ITSESSAAN on toiminnallisesti oikein ja mitattavissa,
  EI VIELA etta koko NTT-ydin hyotyisi siita ilman lisatyota.

## Seuraava askel

1. **3-vaiheinen variantti** - kokeile jakaa Vaihe 1 (68 tasoa)
   edelleen kahtia (esim. `product=a*b` omaksi vaiheekseen, sitten
   `product_times_m` ja `q_est`-erotus omaksi vaiheekseen) - tavoite:
   paasta molemmissa (nyt kolmessa) vaiheessa selvasti alle 60 tasoon.
2. **NTT-ytimen FSM-integraatio** (ERILLINEN, SUUREMPI tyo, EI
   automaattisesti osa tata SYNTH-001-tehtavaa): muuttaa
   `pqc_dilithium_ntt_core.sv`/`pqc_dilithium_ntt_inverse_core.sv`:n
   omaa FSM:aa kayttamaan `pqc_dilithium_barrett_mulmod_pipe2.sv`:ta
   kombinatorisen version sijaan, lisaten tarvittavat odotustilat
   (2 syklia per Barrett-kutsu kombinatorisen 0:n sijaan) ja mittaamaan
   TODELLINEN sykliverkutus koko 256-kertoimiselle NTT-muunnokselle.

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
