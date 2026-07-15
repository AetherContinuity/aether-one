# M4_FPGA_BRAM_STUDY.md — M4-FPGA-002: muistin BRAM-inferointitutkimus

**Päivämäärä:** 2026-07-14
**Tila:** Tutkimusvaihe valmis. EI VIELA arkkitehtuurimuutosta
oikeaan ytimeen.

## Tausta

M4-FPGA-001 osoitti etta `pqc_ntt_stage_banked.sv`:n bring-up-portit
(`FPGA_BRINGUP=1`) tekevat muistipankit synteesille havaittaviksi,
mutta Yosys EI inferoinut niita ECP5:n DP16KD-lohkoiksi - vain
hajautetuksi rekisteri-/LUT-pohjaiseksi logiikaksi (95477 solua).

Tama herattaa kysymyksen: onko kyse tyokaluketjun rajoituksesta
(Yosys/nextpnr-ecp5) vai nykyisen muistiorganisaation (nelja
erillista pankkia + ulkoinen ROM-pohjainen valinta) ominaisuudesta?

**Vastaus, kokeellisesti todistettu: tyokaluketju toimii
odotetusti. Nykyinen muistiorganisaatio estaa inferoinnin.**

## Menetelma

Viisi taysin eristettya, minimaalista SystemVerilog-moduulia
(`hardware/pqc-rtl/fpga/bram_experiments/`), EI kosketa oikeaan
kryptografiseen RTL:aan. Jokainen synteesoitu erikseen samalla
komennolla: `yosys synth_ecp5 -top <moduuli>`.

## Tulokset

| # | Tiedosto | Kuvio | Inferoitu primitiivi | Solumaara | Tulos |
|---|---|---|---|---|---|
| 1 | test1_simple_ram.sv | Yksi muisti, 1 kirjoitus + 1 luku, suora osoite | `DP16KD` x1 | 81 | ✅ TOIMII |
| 2 | test2_four_banks.sv | Nelja pankkia + ulkoinen ROM-pohjainen valinta (= `pqc_ntt_stage_banked`:n OMA nykyinen kuvio) | `TRELLIS_DPR16X4` (hajautettu) | 660 | ❌ EI TOIMI |
| 3 | test3_unified_dualport.sv | Yksi muisti, 1 kirjoitus + 2 lukua | `DP16KD` x2 | 125 | ✅ TOIMII |
| 4 | test4_2w2r.sv | Yksi muisti, 2 kirjoitusta + 2 lukua (4 porttia) | Hajautettu logiikka | 35810 | ❌ EI TOIMI |
| 5 | test5_two_simple_mems.sv | KAKSI erillista yksinkertaista muistia, kumpikin 1+1 porttia | `DP16KD` x2 | 144 | ✅ TOIMII |

(Taydelliset Yosys-lokit ja RTL-lahdekoodi: ks.
`fpga/bram_experiments/*.sv` ja saman hakemiston `RESULTS.md`.)

## Analyysi (KORJATTU — ks. Lisays 2026-07-15 alla, alkuperainen
hypoteesi case-valinnasta oli VIRHEELLINEN)

### Loyto 1 (ALKUPERAINEN, OSITTAIN VIRHEELLINEN): case-pohjainen
pankinvalinta rikkoo inferoinnin

Koe 2 (nykyinen tuotantokuvio) epaonnistuu, vaikka se on LOOGISESTI
identtinen kokeeseen 1/3/5 nahden. Alunperin tulkittu niin, etta
CASE-VALINTALOGIIKKA itsessaan olisi este. **Tama tulkinta osoittautui
VIRHEELLISEKSI - ks. Lisays 2026-07-15.**

### Loyto 2: DP16KD:n porttirajoitus (PYSYY VOIMASSA)

Koe 4 vahvistaa etta ECP5:n DP16KD tukee KORKEINTAAN 2 porttia per
instanssi (ei 4). Tama on ECP5:n oma laitteistorajoitus.

### Loyto 3: paras vastaava kuvio oikealle kayttotarpeelle (TARKENTYY
alla)

Koe 5 (kaksi erillista, suoraan osoitettua muistia) toimi - mutta
KRIITTINEN LISATIETO (ks. alla): tama toimi NIMENOMAAN koska
kokeen 5 muistit olivat 128 alkiota kumpikin, EI koon 64 vuoksi.

## LISAYS 2026-07-15: korjattu, tarkempi juurisyy

Jatkotutkimus (kokeet 6-8, samassa `fpga/bram_experiments/`-
hakemistossa) osoitti etta ALKUPERAINEN hypoteesi (case-pohjainen
pankinvalinta rikkoo inferoinnin) oli **OSITTAIN VIRHEELLINEN**:

- **Koe 6**: SAMA nelja-pankkinen rakenne kuin koe 2, mutta
  ROM-haun sijaan SULJETULLA XOR-kaavalla (`bank = addr[1:0] ^
  addr[3:2] ^ addr[5:4] ^ addr[7:6]`, bijektiivinen, 64/64/64/64-
  jakauma vahvistettu) -> **EDELLEEN EI TOIMI** (TRELLIS_DPR16X4,
  664 solua). Tama kumoaa "ROM vs. suljettu kaava" -hypoteesin.

- **Koe 7**: NELJA erillista 64-alkioista muistia, TAYSIN erillisilla
  porteilla (EI mitaan jaettua osoitetta tai case-valintaa
  lainkaan) -> **EDELLEEN EI TOIMI** (592 solua, hajautettu). Tama
  kumoaa myos "case-valinta itsessaan" -hypoteesin taydellisesti.

- **Koe 8 (kokorajakartoitus)**: YKSI 1w+1r-muisti onnistuu DP16KD:na
  jo koolla 16 alkiota (256 bittia) asti - koko ei ole este YHDELLE
  muistille.

- **Lisakoe (kaksi 64/96/128-alkioista muistia rinnakkain samassa
  moduulissa)**: **n=64 EI TOIMI, n=96 EI TOIMI, n=128 TOIMII**
  (2xDP16KD, 144 solua). Tasmallinen raja loytyy 96:n ja 128:n
  valilta.

- **Vahvistuskoe**: NELJA 128-alkioista muistia (vastaava rakenne
  kuin oikeassa ytimessa, mutta 128 alkiota/pankki 64:n sijaan)
  -> **TOIMII TAYDELLISESTI** (4x DP16KD, vain 288 solua).

### OIKEA JOHTOPAATOS

**Este EI OLE case-pohjainen valinta eika ROM-haku.** Nykyiset kokeet
osoittavat kynnysarvon 96 ja 128 alkion valilla TASSA testatussa
arkkitehtuurissa ja synteesiketjussa - **taman EI PIDA viela tulkita
universaaliksi Yosys-saannoksi** (kayttajan oma, tarkeaa huomio).
Kynnys voisi yhta hyvin johtua bittimaarasta (64x16 vs 128x16),
osoiteleveydesta, muistien lukumaarasta samassa moduulissa, luku-/
kirjoitusporttien muodosta, `memory_bram`-passin sisaisesta
heuristiikasta tai ECP5:n omasta BRAM-pakkaussaannosta - naita EI OLE
eroteltu toisistaan tassa kokeessa.

**Tarkennettu, oikea muotoilu:** "Current experiments indicate a
threshold between 96 and 128 entries under the tested architecture
and synthesis flow."

### Ratkaiseva lisakoe (koe 12, kayttajan oma ehdotus): pankitusalgoritmi
vs. fyysinen jako

Rakennettiin YKSI yhtenainen 256-alkion muisti, jossa looginen osoite
muunnetaan fyysiseksi VAIN sisaisena permutaationa (`physical_addr =
{bank(addr), index(addr)}`, sama XOR-kaava kuin kokeessa 6) - EI
fyysista jakoa neljaan erilliseen taulukkoon.

**Tulos: ✅ 1x DP16KD, vain 99 solua - TAYDELLINEN INFEROINTI.**

Tama on ratkaiseva todiste: **itse pankitusalgoritmi (XOR-kaava) EI
ole ongelma millaan tavalla.** Este on TASMALLEEN fyysinen jako
neljaan pieneen taulukkoon - kun sama looginen kartoitus toteutetaan
YHDEN taulukon SISALLA (osoitepermutaationa), inferointi toimii
taydellisesti.

**Oikean ytimen (`pqc_ntt_stage_banked`) pankit ovat 64 alkiota
kumpikin - JUURI ALLE havaitun 96-128-rajan.** Tama - ei case-valinta,
ei ROM-haku - on todellinen este BRAM-inferoinnille.

### Vaikutus jatkotyohon (PAIVITETTY koe 12:n jalkeen)

Nyt on todistettu KAKSI erillista, toimivaa polkua:

**Vaihtoehto A (koe 11): sailyta nykyinen 4-taulukko-rakenne, kasvata
kokoa.** Minimaalinen muutos - EI kosketa osoitelogiikkaan (case-
valinta, ROM-haku) lainkaan, vain pankkien koko 64:sta esim. 128:aan.
Sailyttaa TASMALLEEN nykyisen ajoituksen (molemmat lanet lukevat+
kirjoittavat samassa syklissa, kuten nyt).

**Vaihtoehto B (koe 12): yksi yhtenainen 256-alkion muisti,
osoitepermutaationa toteutettu pankitus.** Tehokkain (99 solua vs.
288 vaihtoehto A:lla), MUTTA ECP5:n DP16KD tukee korkeintaan 2 porttia
- talla vaihtoehdolla EI voisi tehda molempien laneiden luku+kirjoitus
SAMASSA syklissa kuten nyt (nelja samanaikaista accessia), vaan
ajoitusta pitaisi muuttaa (esim. lanet peraikkain, kaksinkertaistaen
sykliluvun taman muistin osalta) - TAMA ON aidosti suurempi
arkkitehtuurimuutos kuin vaihtoehto A.

**Suositus:** M4-FPGA-002B:n tulisi mitata MOLEMMAT vaihtoehdot
(LUT/FF/EBR/Fmax/syklimaara), mutta vaihtoehto A on todennakoisesti
kaytannollisempi ensimmainen kokeilu koska se ei vaadi ajoitus-
muutoksia - vaihtoehto B saattaa olla parempi PITKALLA aikavalilla
jos ajoitusmuutos osoittautuu hyvaksyttavaksi (esim. jos NTT-ytimen
kokonaislapimenoaika ei ole kriittinen pullonkaula).

## Miksi nykyinen pankkirakenne on olemassa (konteksti, ei kritiikki)

Nelja-pankkinen rakenne + `bank_rom`/`local_rom`-kartoitus kehitettiin
M2:ssa nimenomaan RATKAISEMAAN pankkikonfliktit (kaksi samanaikaista
muistiaccessia, jotka saattaisivat osua samaan fyysiseen pankkiin
tietylla NTT-tasolla) - se on MUODOLLISESTI TODISTETTU rakenne
(ks. M2_DESIGN_NOTE.md) joka takaa konfliktittoman rinnakkaiskayton
KAIKILLA 7 NTT-tasolla. Tama toiminnallinen ominaisuus (konfliktin
esto) on SAAVUTETTU JA TARPEELLINEN - kysymys on VAIN siita, MITEN
sama konfliktiton kartoitus voitaisiin toteuttaa BRAM-yhteensopivalla
tavalla.

## M4-FPGA-002:n jaottelu (kayttajan oma ehdotus)

- **002A**: kokeellinen BRAM-inferointi, muistirakenteiden tutkimus
  (TAMA vaihe - kokeet 1-12, tila: JATKUU edelleen tarvittaessa
  lisakokeilla ennen 002B:hen siirtymista).
- **002B**: valitaan paras muistiorganisaatio (vaihtoehto A vai B,
  ks. ylla) mittausten (LUT/FF/EBR/Fmax/syklimaara) perusteella.
- **002C**: integroidaan valittu ratkaisu oikeaan NTT-ytimeen. Vasta
  tassa vaiheessa kosketaan varsinaiseen kryptografiseen RTL:aan.

## KRIITTINEN LISAYS 2026-07-17: tutkimuskysymys jakautuu kahtia

Ennen prototyyppien A/B rakentamista havaittiin merkittava
sekoittava tekija KAIKISSA aiemmissa "onnistuneissa" kokeissa
(10, 11, 12): ne kaikki kayttivat REKISTEROITYA lukua (`always_ff`),
kun taas OIKEA `pqc_ntt_stage_banked` kayttaa KOMBINATORISTA lukua
(`always_comb`, ks. rivit 122-140 - `rdata_a0` jne. paivittyvat
SAMALLA syklilla kuin osoite, ei syklin viiveella).

Testattu eksplisiittisesti:
- YKSI 256-alkion yhtenainen muisti, MUTTA kombinatorisella luvulla
  -> **EI TOIMI** (645 solua, hajautettu) - vaikka SAMA muisti
  rekisteroidylla luvulla TOIMII (koe 1, 81 solua).
- NELJA 128-alkioista pankkia, kombinatorisella luvulla -> **EI
  TOIMI** (928 solua, hajautettu) - vaikka SAMA rakenne rekisteroidylla
  luvulla TOIMII (koe 11, 288 solua).

**Tama muuttaa tutkimuskysymyksen kahtia (kayttajan oma jaottelu):**

1. **Voiko Yosys inferoida ECP5 BRAM:n asynkronisesta/kombinatorisesta
   lukurajapinnasta?** Nayttoni: EI, riippumatta muistiorganisaatiosta.
   Tama on RIIPPUMATON kysymys muistin koosta tai fyysisesta
   jakautumisesta.
2. **Jos luku on synkroninen, mika muistiorganisaatio on paras?**
   Tahan nayttoni jo osoittaa: seka yhtenainen RAM etta riittavan
   suuri pankkirakenne (>=128 alkiota/pankki) voivat inferoitua
   DP16KD:ksi.

**Seuraus:** pelkka muistien uudelleenjarjestely (koko/rakenne) EI
KOSKAAN ratkaise oikean ytimen ongelmaa, koska este on ENSISIJAISESTI
lukurajapinnan AJOITUS (kombinatorinen vs. rekisteroity), ei
muistin koko tai organisaatio. Tama vaatii `lane_fsm`:n oman
ajoitusprotokollan tarkastelua ENNEN kuin prototyypit A/B ovat
mielekkaita.

## Seuraava koe (kayttajan oma ehdotus): voiko lane_fsm toimia yhden
syklin lukuviiveella ilman algoritmimuutoksia?

Minimaalinen koe: nykyinen `lane_fsm` (MUUTTUMATON), nykyinen
osoitegenerointi, MUTTA rekisteroity testimuisti (EI NTT-laskentaa) -
tarkastellaan VAIN osoitteiden, `read_valid`-tyyppisen signaalin ja
FSM-tilojen ajoitusta. Vastaa kysymykseen: onko `lane_fsm` rakennettu
NOLLAVIIVEISEN muistin varaan (vaatisi FSM:n uudelleenajoituksen), vai
voidaanko yhden syklin lukuviive lisata ilman muutoksia butterfly-
laskentaan?

Tulos: ks. alla.

## Johtopaatos ja suositus (PAIVITETTY 2026-07-16)

**EI VIELA muutosta oikeaan ytimeen.** Loydokset (mukaan lukien
korjattu, tarkempi juurisyy - kokoraja, ei case-valinta) antavat
VAHVAN, KOKEELLISESTI TODISTETUN perustelun mahdolliselle tulevalle
tyolle, mutta paatos siita TEHDAANKO muutos vaatii ensin (kayttajan
oma jarjestys):

1. **M4-FPGA-002A**: prototyyppi jossa pankkien koko kasvatetaan
   64:sta vahintaan 128:aan (ylimitoitus TAI kahden NTT-tason
   taittaminen samaan fyysiseen pankkiin) - EI muutoksia butterfly-
   laskentaan, NTT-algoritmiin, EIKA valttamatta edes osoitelogiikkaan
   (case-valinta ja ROM-haku voivat pysya ennallaan, koon kasvatus
   riittanee yksinaan).
2. **M4-FPGA-002B**: mittaa ja vertaa (LUT, FF, EBR, Fmax,
   syklimaara) nykyisen ja prototyypin valilla.
3. Vasta jos luvut osoittavat SELVAN hyodyn, harkita nykyisen
   pankkirakenteen (koon) muuttamista tuotannossa.

Tama pitaa optimointityon todisteisiin perustuvana, ei arvauksena.
Korjattu ymmarrys (kokoraja, ei rakenne) tekee mahdollisesta
korjauksesta todennakoisesti YKSINKERTAISEMMAN kuin alunperin
arvioitiin.
