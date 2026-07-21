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

## Toteutus ja tulokset (2026-07-21) - VAIHE 2/2 SUORITETTU (Baseline + 2-vaiheinen pipeline)

**Status paivitetty: Open -> osittain suoritettu (2-vaiheinen variantti
VALMIS ja MITATTU, 3-vaiheinen viela avoin).**

### Toteutettu

- `pqc_dilithium_barrett_mulmod_pipe2.sv`: 2-vaiheinen rekisteroity
  versio, jako TASMALLEEN `q_est`:n laskennan jalkeen (ks. "Muutos"
  ylla). Kiintea 2 syklin latenssi.
- `barrett_pipe2_tb.sv`: toiminnallinen testi, VERTAA pipe2:n
  ulostuloa SUORAAN alkuperaisen kombinatorisen `pqc_dilithium_
  barrett_mulmod.sv`:n tulokseen 100 000 satunnaisella (a,b)-parilla
  (sama testimetodologia kuin alkuperaisen moduulin oma 100000-
  parin todennus).
- `pqc_dilithium_barrett_pipe2_stage1_measure.sv` /
  `..._stage2_measure.sv`: kumpikin pipeline-vaihe ERISTETTYNA
  puhtaasti kombinatorisena moduulina, JOTTA `ltp` voidaan mitata
  KUMMALLEKIN vaiheelle ERIKSEEN (ei koko pipe2-moduulille kerralla,
  mika antaisi vain suuremman VAIHEEN oman luvun).

### Mitatut tulokset

| Mittari | Baseline (0-vaihe) | 2-vaiheinen pipeline |
|---|---|---|
| `ltp` Vaihe 1 | 107 (koko moduuli) | **68** |
| `ltp` Vaihe 2 | - | **41** |
| Solumaara (koko moduuli) | 6 517 | **6 685** (+2.6%) |
| FF-maara | 0 | **93** (tasmaa odotukseen: product_reg 46b + q_est_reg 24b + result_reg 23b = 93b) |
| Toiminnallinen oikeellisuus | - | **PASS 100 000/100 000** satunnaista (a,b)-paria, tasmaa alkuperaiseen kombinatoriseen tulokseen tasmalleen |

### Hyvaksymiskriteerin tarkistus

| Kriteeri | Tulos |
|---|---|
| (a) `ltp` selvasti alle 107/vaihe, tavoite <60/vaihe | **OSITTAIN**: Vaihe 2 (41) ALITTAA tavoitteen selvasti. Vaihe 1 (68) ON merkittava parannus (-36% baselinesta) mutta EI aivan alita 60:n tavoitetta - epasymmetria selittyy silla etta Vaihe 1 sisaltaa KAKSI kertolaskua (a*b JA product*M_CONST) kun Vaihe 2 sisaltaa vain YHDEN (q_est*Q) + vahennyksen. |
| (b) Olemassa olevat Unit-/Component-tason testit pysyvat vihreina | **EI VIELA SOVELLETTAVISSA** - `pqc_dilithium_ntt_core.sv` KAYTTAA EDELLEEN alkuperaista, kombinatorista `barrett_mulmod`:ia. Pipe2-moduulia EI OLE VIELA integroitu NTT-ytimeen (tama olisi ERILLINEN, laajempi FSM-muutos - ks. "Seuraava askel" alla). NTT-ytimen omat testit EIVAT siis ole voineet rikkoutua, koska mitaan olemassa olevaa TIEDOSTOA ei ole muutettu. |
| (c) Sykliverkutus kohtuullinen | **EI VIELA MITATTAVISSA** - vaatii integraation (b:n tapaan). |

### Rehellinen johtopaatos

**Barrett-modulokertolaskun 2-vaiheinen pipeline ON TOTEUTETTU,
TOIMINNALLISESTI TODENNETTU (100% tasmaavuus 100000 satunnaisella
parilla) ja MITATTU (`ltp` 107 -> 68/41, FF 0->93, solut +2.6%).**
Tama VAHVISTAA etta pipelinointi ON toimiva, konkreettinen keino
lyhentaa kriittista polkua - mutta koska Vaihe 1 EI aivan yllä
alkuperaiseen <60-tason tavoitteeseen, HARKITSE 3-vaiheista varianttia
(jakaen Vaihe 1:n oman kahden kertolaskun valiin) TAI hyvaksy 68
tasoa "riittavan hyvana" parannuksena (36% lyhennys) - tama on
tietoinen paatos joka jaa avoimeksi jatkokeskustelulle.

**TARKEA RAJAUS: taman pipeline-moduulin INTEGROINTI `pqc_dilithium_
ntt_core.sv`:aan EI SISALTYNYT taman kierroksen tyohon** - NTT-ydin
kayttaa Barrett-mulmod:ia OMAN FSM:nsa yhden tilan sisalla olettaen
YHDEN SYKLIN latenssin (kombinatorinen); pipe2:n 2 syklin latenssi
vaatisi NTT-ytimen OMAN FSM:n muokkaamisen (joko lisaamalla odotus-
tiloja, tai suunnittelemalla butterfly-silmukka uudelleen pipeline-
tayttoa hyodyntavaksi). TAMA ON OMA, ERILLINEN seuraava askel (ks.
alla) - EI viela tehty, EIKA VAADITTU taman SYNTH-001-tehtavan
kapean rajauksen puitteissa (ks. "Rajaukset"-osio ylla, joka
ALUNPERIN rajasi tehtavan YHTEEN moduuliin).

### Seuraava askel (jos jatketaan)

1. Paattaa: riittaako 68/41-tason parannus, vai kokeillaanko viela
   3-vaiheista varianttia Vaihe 1:n oman jakamiseksi.
2. JOS pipe2 (tai 3-vaiheinen) paatetaan OTTAA KAYTTOON tuotannossa:
   suunnitella `pqc_dilithium_ntt_core.sv`:n OMAN FSM:n muutos joka
   huomioi 2 (tai 3) syklin latenssin - TAMA on merkittavasti
   suurempi muutos kuin taman kierroksen oma tyo, ansaitsisi OMAN
   SYNTH-002-tehtavansa.
3. Fmax-vaikutus jaa edelleen mittaamatta (sama P&R-resurssirajoite
   kuin baseline:lla) - `ltp`:n oma vahennys (107->68/41) ON
   KUITENKIN vahva, tyokaluriippumaton signaali odotettavissa
   olevasta parannuksesta.

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
