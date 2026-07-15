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

**Este EI OLE case-pohjainen valinta eika ROM-haku. Este on
YKSITTAISEN MUISTIN KOKO, KUN MODUULISSA ON USEAMPI MUISTI
RINNAKKAIN.** Yosysin `memory_bram`-vaiheen paatoslogiikka
(todennakoisesti: BRAM-instanssin "hyoty" verrattuna sen omaan
kiinteaan kokoon, 16Kbit per DP16KD) nayttaa arvioivan useamman
pienen muistin tapauksessa eri tavalla kuin yhden ainoan - tarkkaa
Yosysin sisaista paatoslogiikkaa ei ole tassa selvitetty tarkemmin,
vain sen KAYTTAYTYMINEN mitattu kokeellisesti.

**Oikean ytimen (`pqc_ntt_stage_banked`) pankit ovat 64 alkiota
kumpikin - JUURI ALLE havaitun 96-128-rajan.** Tama - ei case-valinta,
ei ROM-haku - on todellinen este BRAM-inferoinnille.

### Vaikutus jatkotyohon

Mahdollinen korjaus on siis YKSINKERTAISEMPI kuin alunperin arvioitu:
EI tarvita mitaan muutosta osoitelogiikkaan (case-valinta ja/tai
ROM-haku voivat pysya TASMALLEEN ennallaan) - riittaisi PELKASTAAN
kasvattaa kunkin pankin kokoa vahintaan 128 alkioon (esim. taittamalla
2 NTT-tasoa yhteen fyysiseen pankkiin, tai yksinkertaisesti
ylimitoittamalla pankit 64:sta 128:aan kayttamatta puolta tilasta).
Tama on kevyempi, vahemman invasiivinen muutos kuin taydellinen
osoitelogiikan uudelleensuunnittelu - MUTTA vaatii oman, huolellisen
arviointinsa (esim. resurssien haaskaus, kaksi NTT-tasoa yhdessa
pankissa -skeeman vaikutus konfliktittomuustodistukseen) ennen
soveltamista.

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

## Johtopaatos ja suositus (PAIVITETTY 2026-07-15)

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
