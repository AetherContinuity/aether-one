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

## Analyysi

### Loyto 1: case-pohjainen pankinvalinta rikkoo inferoinnin taysin

Koe 2 (nykyinen tuotantokuvio) epaonnistuu, vaikka se on LOOGISESTI
identtinen kokeeseen 1/3/5 nahden (sama data, sama kayttaytyminen) -
ero on VAIN siina, ETTA looginen->fyysinen osoite kulkee ULKOISEN
ROM-taulukon (`bank_rom`/`local_rom`) kautta ENNEN muistin omaa
osoitesyotetta, sen sijaan etta osoite menisi SUORAAN muistiin.

Yosysin `memory_bram`-vaihe (osa `synth_ecp5`-skriptia) tunnistaa
BRAM-kelpoiset kuviot TARKISTAMALLA etta osoitesignaali kulkee
suoraan porttiin ilman valissa olevaa, EPASAANNONMUKAISTA (data-
riippuvaista, ei-lineaarista) muunnosta. `bank_rom[addr]`-haku on
tallainen muunnos - vaikka se on TAYSIN DETERMINISTINEN JA STAATTINEN
(kiinteat arvot, ladattu kerran alussa), Yosys ei paattele etta
tulos on silti suora, yksi-yhteen-kartoitus joka voitaisiin
"nahda lapi" BRAM-inferointia varten.

### Loyto 2: DP16KD:n porttirajoitus

Koe 4 vahvistaa etta ECP5:n DP16KD tukee KORKEINTAAN 2 porttia per
instanssi (ei 4). Tama on ECP5:n oma laitteistorajoitus, ei
Yosys-kohtainen. Jos tarvitaan enemman kuin 2 porttia SAMALLE
muistialueelle SAMASSA syklissa, ratkaisu on JOKO:
(a) useampi muisti-instanssi (jokainen omalla, erillisella
    data-alueellaan), TAI
(b) porttimaaran vahentaminen ajoituksen (useamman syklin) kautta.

### Loyto 3: paras vastaava kuvio oikealle kayttotarpeelle

Koe 5 (kaksi erillista, suoraan osoitettua muistia) vastaa lahinna
`pqc_ntt_stage_banked`:n oikeaa tarvetta (lane0 ja lane1 lukevat+
kirjoittavat samanaikaisesti, jokainen omalla portillaan) - MUTTA
ilman case-pohjaista pankinvalintaa, suoralla per-muisti-osoitteella.

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

## Johtopaatos ja suositus

**EI VIELA muutosta oikeaan ytimeen.** Loydokset antavat VAHVAN,
KOKEELLISESTI TODISTETUN perustelun mahdolliselle tulevalle
arkkitehtuurityolle, mutta paatos siita TEHDAANKO muutos vaatii
ensin (kayttajan oma jarjestys):

1. **M4-FPGA-002A**: prototyyppi suoralla, muistikohtaisella
   osoitteistuksella (ei case-pohjaista ulkoista valintaa) - EI
   muutoksia butterfly-laskentaan tai NTT-algoritmiin, VAIN
   osoitteenmuodostustapa.
2. **M4-FPGA-002B**: mittaa ja vertaa (LUT, FF, EBR, Fmax,
   syklimaara) nykyisen ja prototyypin valilla.
3. Vasta jos luvut osoittavat SELVAN hyodyn, harkita nykyisen
   pankkirakenteen korvaamista tuotannossa.

Tama pitaa optimointityon todisteisiin perustuvana, ei arvauksena.
