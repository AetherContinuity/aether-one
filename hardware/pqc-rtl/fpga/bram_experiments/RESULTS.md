# M4-FPGA-002, koe 1: mika muistirakenne inferoituu ECP5 DP16KD:ksi Yosysilla

**Tavoite (kayttajan oma kysymys #1):** selvittaa millainen
muistirakenne inferoituu ECP5:n DP16KD-lohkoihin Yosysilla, ennen
kuin kosketaan oikeaan kryptografiseen RTL:aan.

Kaikki kokeet: `yosys synth_ecp5`, sama tyokaluketju kuin
M4-FPGA-001:ssa.

| # | Kuvio | Tulos | Solumaara |
|---|---|---|---|
| 1 | Yksi muisti, 1w+1r, suora osoite | ✅ 1x DP16KD | 81 |
| 2 | Nelja pankkia + ulkoinen ROM-pohjainen valinta (= pqc_ntt_stage_banked:n oma kuvio, 64 alkiota/pankki) | ❌ TRELLIS_DPR16X4 (hajautettu) | 660 |
| 3 | Yksi muisti, 1w+2r (kaksi lukuporttia) | ✅ 2x DP16KD | 125 |
| 4 | Yksi muisti, 2w+2r (nelja porttia) | ❌ Hajautettu logiikka | 35810 |
| 5 | Kaksi erillista muistia, 128 alkiota kumpikin, kumpikin 1w+1r | ✅ 2x DP16KD | 144 |
| 6 | Nelja pankkia, SULJETULLA XOR-kaavalla ROM-haun sijaan (64 alkiota/pankki) | ❌ TRELLIS_DPR16X4 (hajautettu) | 664 |
| 7 | Nelja ERILLISTA 64-alkioista muistia, taysin erillisilla porteilla (ei jaettua osoitetta/valintaa) | ❌ TRELLIS_DPR16X4 (hajautettu) | 592 |
| 8 | Kokorajakartoitus, yksi muisti: 16/32/64/128/256/512 alkiota | ✅ DP16KD KAIKILLA kooilla | vaihtelee |
| 9 | Kaksi 64-alkioista muistia rinnakkain | ❌ Hajautettu | 296 |
| 10 | Kaksi 128-alkioista muistia rinnakkain | ✅ 2x DP16KD | 144 |
| 11 | Nelja 128-alkioista muistia rinnakkain (kuten oikea ydin, mutta 128 alkiota/pankki 64:n sijaan) | ✅ 4x DP16KD | 288 |
| 12 | YKSI yhtenainen 256-alkion muisti, pankitus XOR-kaavalla VAIN osoitepermutaationa (ei fyysista jakoa) | ✅ 1x DP16KD | 99 |

## KORJATTU johtopaatos (2026-07-15, tarkennettu 2026-07-16)

**Alkuperainen tulkinta (kokeet 1-5): "case-pohjainen pankinvalinta
rikkoo inferoinnin" - OSOITTAUTUI VIRHEELLISEKSI.**

Kokeet 6-11 osoittivat kokoraja-ilmion (ks. yksityiskohdat
`../M4_FPGA_BRAM_STUDY.md`) - **HUOM: taman EI PIDA viela tulkita
universaaliksi Yosys-saannoksi**, vain empiiriseksi havainnoksi
TASSA testatussa arkkitehtuurissa (kayttajan oma, tarkea huomio).

**Koe 12 (ratkaiseva): kun sama XOR-pankituskaava toteutetaan YHDEN
yhtenaisen 256-alkion muistin SISALLA osoitepermutaationa (ei
fyysista jakoa neljaan tauluun), inferointi TOIMII TAYDELLISESTI
(1x DP16KD, 99 solua).** Tama todistaa lopullisesti: itse
pankitusalgoritmi (XOR-kaava) EI ole millaan tavalla ongelma - este
on TASMALLEEN fyysinen jako useampaan pieneen taulukkoon.

**JUURISYY: yksittaisen muistin KOKO, kun moduulissa on useampi
muisti rinnakkain - EI pankitusalgoritmi (case/ROM/XOR-kaava).**
Kynnys (havaittu 96-128 alkion valilla) on empiirinen havainto TASSA
testatussa konfiguraatiossa - ei viela vahvistettu universaaliksi
saannoksi. Oikean ytimen pankit (64 alkiota) ovat kokeissa
havaitun kynnyksen alapuolella.

Taydellinen analyysi: ks. `../M4_FPGA_BRAM_STUDY.md`.

## Ei viela tehty

Ei kosketa pqc_ntt_stage_banked.sv:aan tassa kokeessa - taydellisesti
eristetyt, minimaaliset kokeilumallit fpga/bram_experiments/-
hakemistossa. Mahdollinen korjaus (pankkien koon kasvatus 64:sta
128:aan) on oma, erillinen paatoksensa - todennakoisesti KEVYEMPI
muutos kuin alunperin arvioitu osoitelogiikan uudelleensuunnittelu,
mutta vaatii silti oman, huolellisen arviointinsa (resurssien
kaytto, mahdollinen vaikutus konfliktittomuustodistukseen jos
pankkien maaraa tai kokoa muutetaan) ennen toteutusta.
