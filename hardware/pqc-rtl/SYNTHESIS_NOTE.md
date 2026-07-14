# Synteesikelpoisuuden tarkistus (2026-07-11)

## 1. Verilator-lint: yksi todellinen este löytyi ja korjattiin

`lane_fsm`:n `pair_dist`-portilla oli oletusarvo (`= 8'd1`), lisätty
taaksepäinyhteensopivuuden vuoksi M2 Vaihe 2c:ssä. Verilator ei tue
oletusarvoja moduulien porteille lainkaan (`Unsupported: Default value
on module input`).

**Korjattu:** oletusarvo poistettu, kaikki instanssit (myös M1/M2 Vaihe 1,
jotka aiemmin nojasivat oletukseen) kytkevät `pair_dist`:n nyt
eksplisiittisesti. Regressiotestattu kaikki 8 aiempaa testiä
(M1/Vaihe1/2b/2c-i/2c-ii/3a/3b/3c/3d) - PASS muuttumattomana.

Jäljelle jäävät Verilator-varoitukset (20 kpl) ovat kaikki vaarattomia
(käyttämätön signaali, implisiittinen bittileveyden pyöristys,
nimeämiskäytäntö) - ei estä synteesiä.

## 2. Geneerinen Yosys-synteesi: onnistui

`pqc_ntt_stage_banked` (M2 Vaihe 3c:n oikein mitoitettu moduuli,
SPAD_AW=9): synteesi onnistuu, tuottaa **~4224 flip-flopia, ~45613
solua yhteensä** (mukaan lukien ~28886 geneeristä MUX-solua).

Muistiobjektit säilyvät oikein (`memory -nomap` -tarkistus vahvistaa:
6 `$mem_v2`-objektia - bank0-3 + bank_rom + local_rom, täsmälleen
odotetusti).

M1:n vanha, ylimitoitettu testirakennelma (SPAD_AW=15 oletuksena,
2^15=32768 osoitetta vaikka vain 256 tarvitaan) räjäytti geneerisen
synteesin (32768 flip-flopia, 131068 mux-solua, prosessi killattiin) -
tämä on M1:n oman testauskehyksen ylimitoitus, ei koske M2:n oikeaa
putkea.

## 3. ECP5-teknologiamäppäys: avoin tekninen kysymys, ei vielä paikallistettu

`synth_ecp5 -top pqc_ntt_stage_banked` tuottaa **~287 solua, 30
flip-flopia, EI YHTÄÄN DP16KD-muistilohkoa** - noin 150-kertaisesti
pienempi kuin geneerinen tulos.

**Mitä on osoitettu (kokeellisesti, ei päätelty):**
- `$readmemh` ei ole yleisesti ongelma Yosysissa: eristetty testi
  (yksi 256-alkioinen ROM-haku) tuottaa oikein ~70 mux-solua geneerisellä
  `synth`:lla, käyttäen samaa `$readmemh`-mekanismia.
- Muistiobjektit eivät katoa Verilog-jäsentämisessä: `proc; memory
  -nomap` -tarkistus (ennen mitään teknologiakartoitusta) näyttää
  kaikki 6 muistiobjektia oikein, realistisella oheislogiikalla
  (~490 solua, 14 kertolaskua, 237 muxia).
- `(* keep *)`-attribuutit muistitaulukoilla eivät muuttaneet
  ECP5-tulosta.
- ROM:in korvaaminen `$readmemh`:n sijaan suoraan upotetulla
  vakiotaulukolla ei ole vielä testattu onnistuneesti (syntaksivirhe
  omassa testikoodissa, ei korjattu tässä kierroksessa).

**Mitä EI ole osoitettu:**
- Ei ole eristetty täsmällistä `synth_ecp5`-sisäistä vaihetta (esim.
  `memory_bram`) jossa muistiobjektit katoavat.
- Ei ole todistettu onko kyse muistimallin muodosta (bank0-3:n
  luku/kirjoitusporttien rakenne, tai bank_rom/local_rom:in epätavalliset
  2-bit/6-bit leveydet) joka ei täytä ECP5:n EBR-sääntöjä, vai
  työkaluketjun omasta rajoitteesta.

**Johtopäätös:** Geneerinen Yosys-synteesi tuottaa odotetun rakenteen
ja säilyttää muistikohteet. ECP5-teknologiamäppäyksessä havaitaan
poikkeava lopputulos, jossa resurssiarvio ei vastaa geneeristä
rakennetta. Nykyisten kokeiden perusteella poikkeama syntyy
teknologiamäppäysvaiheen aikana tai sen jälkeen, mutta tarkkaa vaihetta
ei ole vielä paikallistettu. Tämä on avoin tekninen kysymys, ei
todistettu työkaluketjun virhe.

**Huomio vertailtavuudesta:** geneerisen synteesin 4224 FF ja ECP5:n
30 FF eivät välttämättä ole suoraan vertailukelpoisia sellaisenaan -
teknologiamäppäys voisi periaatteessa siirtää tilaa EBR-lohkoihin tai
optimoida datapolkuja eri tavoin. Suuri numeroero on hyvä syy epäillä
ongelmaa, mutta ei yksin lopullinen todiste siitä.

## Seuraava askel (jos ECP5-toteutus tulee ajankohtaiseksi)

1. Aja `synth_ecp5`:n sisäiset vaiheet erikseen (ei yhtenä makrona).
2. Tallenna RTLIL jokaisen muistipassin jälkeen.
3. Tarkista täsmälleen missä vaiheessa `$mem`-objektit muuttuvat tai
   katoavat.
4. Vasta sen jälkeen päätellä: muistimallin muoto, `memory_bram`-
   sääntöjen täyttymättömyys, vai työkaluketjun rajoite.

**Tätä ei tehty tässä kierroksessa** - päätetty pysähtyä ja raportoida
tarkka, todistettu tila sen sijaan että jatkettaisiin arvailua.
Toiminnallisesti verifioitu RTL + muodollinen muistikuvauksen todistus
+ onnistunut geneerinen synteesi riittävät jatkamaan algoritmi- ja
arkkitehtuuritason kehitystä ilman ECP5-spesifista resurssiraporttia.

## M3 Release Candidate -tarkistus (2026-07-14)

Kayttajan oma RC-vaatimus: tarkista ettei synteesissa synny uusia
varoituksia tai inferoituja latch-rakenteita.

**Verilator-lint (-Wall), KAIKKI rtl/*.sv-tiedostot erikseen:**
haettiin nimenomaisesti LATCH-, UNDRIVEN- ja COMBDLY-varoituksia
(latch-inferointi olisi vakava, synteesikelpoisuutta rikkova loydos) -
**EI YHTAAN LOYTYNYT koko RTL-hakemistosta.** Jaljella olevat
Verilator-varoitukset (WIDTHTRUNC, WIDTHEXPAND, DECLFILENAME) ovat
samaa, jo aiemmin (2026-07-11) todettua vaaratonta luokkaa - implisiit-
tinen bittileveyden pyoristys funktioargumenteissa, ei toiminnallinen
riski.

**Yosys-synteesi, kaksi keskeista moduulia erikseen tarkistettu:**
- `pqc_ntt_stage_banked` (+lane_fsm): 375 solua, 6 muistia (bank0-3 +
  ROMit), 0 virhetta, 2 vaaratonta muistivaroitusta (pieni rekisteri-
  taulukko optimoitu suoraan flip-flopeiksi muistiobjektin sijaan -
  odotettu, ei ongelma).
- `pqc_keccak_f1600` (permutaatioydin): 358 solua, 0 virhetta, 6
  samanlaista vaaratonta muistivaroitusta (5x5-tilataulukon sisaiset
  valivaiheet C/D/B/A_theta/A_next/A - kaikki pienia, synteesi
  optimoi ne oikein rekistereiksi).

**Johtopaatos:** ei uusia varoituksia, ei latch-inferointia, molemmat
tarkistetut moduulit synteesoituvat puhtaasti. Taydellinen ECP5-
spesifinen resurssi-/ajoitusraportti (aiemmin tunnistettu BRAM-mappaus-
kysymys, ks. ylla) jaa edelleen omaksi, myohemmaksi tyokseen - tama
RC-tarkistus kattaa geneerisen synteesikelpoisuuden, ei FPGA-
kohdekohtaista optimointia.
