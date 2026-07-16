# M4-FPGA-006: kriittisen polun analyysi ja pipelinointikandidaatti

**Paivamaara:** 2026-07-19
**Lahtokohta:** M4-FPGA-005:n vahvistama Fmax=21.21 MHz, kriittinen
polku `core.lane1.bp_reg`

## Sykliluku per NTT (kontekstitieto Fmax-arviointiin)

| NTT_READ_LATENCY | Sykliä yhteensa (7 tasoa) | Ylikustannus |
|---|---|---|
| 0 (kombinatorinen) | 1540 | 196 (start-pulssit) |
| 1 (BRAM-yhteensopiva) | 1988 | 644 (196 + 448 yhden syklin READ_LATENCY-lisays) |

448 lisasyklia tasmaa TARKALLEEN odotukseen: yksi ylimaarainen sykli
per (lane, iteraatio) -pari, 448 = 2 lanea x 224 iteraatiota
(896 butterfly-operaatiota / 2 lanea x 1 sykli).

**Kokonaisaika 21.21 MHz:lla:** 1988 sykliä / 21.21 MHz ≈ **93.7
mikrosekuntia** per taydellinen 256-kertoiminen ML-KEM-512-NTT.

## Kriittisen polun tarkka rakenne (koodista jaljitetty)

`rtl/pqc_rvv_cluster_2lane.sv`, rivit 182-183 (FORWARD-suunta):

```systemverilog
ap_reg <= mod_add(a_reg, montgomery_reduce(b_reg * zeta_in));
bp_reg <= mod_sub(a_reg, montgomery_reduce(b_reg * zeta_in));
```

`montgomery_reduce`-funktio (rivit 99-111):

```systemverilog
a_lo   = a[15:0];
t16    = a_lo * QINV;      // KERTOLASKU #2
prod   = t16 * Q;          // KERTOLASKU #3
result = (a - prod) >>> 16;
if (result < 0) result += Q;
else if (result >= Q) result -= Q;
```

**KOLME 16x16-bittista kertolaskua ketjutettuna YHTEEN sykliin, ilman
rekisterointia valissa:**
1. `b_reg * zeta_in` (butterfly-kertolasku)
2. `a_lo * QINV` (Montgomery-redusoinnin oma kertolasku)
3. `t16 * Q` (Montgomery-redusoinnin toinen kertolasku)

Jokainen kertolasku kayttaa todennakoisesti oman `MULT18X18D`-DSP-
lohkonsa (synteesiraportissa 6 kpl kaytossa) - mutta KOLMEN DSP-
lohkon KETJUTTAMINEN ilman valissa olevaa rekisteria on juuri
sellainen rakenne joka tyypillisesti rajoittaa Fmax:aa merkittavasti,
tasmaten M4-FPGA-005:n havaitsemaan 20.5 ns logiikka-aikaan.

## Pipelinointikandidaatti (EI VIELA toteutettu - vaatii oman,
huolellisen tyopakettinsa)

Luonnollinen 3-4-vaiheinen liukuhihna:

| Vaihe | Operaatio |
|---|---|
| 1 | `t = b_reg * zeta_in` (rekisteroi tulos) |
| 2 | `t16 = t[15:0] * QINV` (rekisteroi tulos) |
| 3 | `prod = t16 * Q`, `result = (t - prod) >>> 16` (rekisteroi) |
| 4 | Range-korjaus + `mod_add`/`mod_sub` lopputulos |

**Odotettu vaikutus:** Fmax todennakoisesti nousisi merkittavasti
(DSP-lohkojen omat propagaatioviiveet, ~2-4 ns kukin ECP5:lla,
sallisivat huomattavasti korkeamman kellotaajuuden kun ne erotetaan
omiksi sykleikseen) - MUTTA jokainen butterfly-operaatio veisi 3-4
sykliä nykyisen 1 syklin sijaan, kasvattaen KOKONAISSYKLIMAARAA
vastaavasti. Nettosuorituskyky (todellinen NTT-aika sekunteina)
riippuu siita, kasvaako Fmax ENEMMAN kuin sykliluku kasvaa.

**Tama on OMA, myohempi tyopakettinsa** (kayttajan oma nakemys) -
vaatisi:
1. Golden-mallin regressio pipelinoidulle versiolle (sama menetelma
   kuin M4-FPGA-002D/003A:ssa).
2. Uusi P&R-ajo pipelinoidulla versiolla, Fmax-vertailu.
3. Nettosuorituskykyvertailu (aika = syklit / Fmax) VANHAN ja UUDEN
   valilla - vasta talloin voidaan sanoa onko pipelinointi aidosti
   hyodyllinen taman jarjestelman kayttotapaukselle.

## Ei viela paatosta pipelinoinnista

Kayttajan oma nakemys: 21 MHz "ensimmaisessa tuotantoversiossa" ei
ole poikkeuksellinen, jos butterfly on pitka kombinatorinen ketju -
tama analyysi VAHVISTAA etta nain juuri on (kolme ketjutettua
kertolaskua). Tama dokumentti kirjaa loydetyn pullonkaulan tarkasti,
mutta EI VIELA tee paatosta pipelinoinnin toteuttamisesta - se on
seuraavan, erillisen tyopaketin oma paatos.

## TARKENNUS: reititys on itse asiassa hieman logiikkaa suurempi

Tarkka jakauma raportista: **20.5 ns logiikkaa, 22.9 ns REITITYSTA**
(yhteensa 43.4 ns, vastaten 23.04 MHz - lahella raportoitua 21.21
MHz:aa huomioiden lisaviiveet).

**Tama on tarkea rajoitus pipelinoinnin odotetulle hyodylle:**
kolmen DSP-kertolaskun ketju selittaa LOGIIKKA-osuuden (20.5 ns),
mutta REITITYS-osuus (22.9 ns) riippuu DSP-lohkojen ja LUT:ien
FYYSISESTA SIJOITTELUSTA piirilla - pelkka pipelinointi (rekisterien
lisays) EI automaattisesti paranna reititysta, ellei nextpnr MYOS
sijoita lyhyempia logiikkalohkoja lahemmaksi toisiaan tuloksena.

## Perustaso ja kannattavuuslaskelma (kayttajan oma vaatimus:
lapimenoaika, ei pelkka Fmax)

**Nykyinen perustaso: 1988 sykliä / 21.21 MHz = 93.73 mikrosekuntia
per taydellinen NTT.**

Esimerkkiskenaarioita (mita Fmax-parannus vaatisi kannattaakseen eri
sykli-lisayksilla per butterfly, 448 lane-iteraatiota):

| Lisasykli/bf | Fmax x1.5 | Fmax x2.0 | Fmax x2.5 | Fmax x3.0 |
|---|---|---|---|---|
| +1 | 76.6us (+18%) | 57.4us (+39%) | 45.9us (+51%) | 38.3us (+59%) |
| +2 | 90.7us (+3%) | 68.0us (+28%) | 54.4us (+42%) | 45.3us (+52%) |
| +3 | 104.7us (**-12%, HUONONTUU**) | 78.6us (+16%) | 62.8us (+33%) | 52.4us (+44%) |

**Johtopaatos:** koska reititys on jo NYT suurempi kuin logiikka,
realistinen odotettu Fmax-parannus 3-vaiheisesta pipelinoinnista on
todennakoisesti LAHEMPANA 1.5-2x kuin naiivia 3x (joka olettaisi
koko viiveen olevan logiikkaa). Talla vaihteluvalilla nettohyoty
on VAATIMATON (+3% .. +39%) tai jopa NEGATIIVINEN jos pipelinointi
vaatii enemman kuin 1-2 lisasyklia per butterfly.

**Tama EI tarkoita etta pipelinointi kannattaisi hylata** - se
tarkoittaa etta paatos on tehtava MITATUN, ei oletetun, Fmax-
parannuksen perusteella (kayttajan oma vaatimus).

## Hyvaksymiskriteerit seuraavalle tyopaketille (M4-FPGA-007,
EI VIELA aloitettu)

- ✅ Algoritminen ekvivalenssi sailyy (golden trace PASS)
- ✅ DP16KD=4 sailyy
- ✅ Fmax nousee MITATUSTI (uusi P&R-ajo, ei arvio)
- ✅ **Lapimenoaika (mikrosekuntia/NTT = uudet_syklit/uusi_Fmax)
  ON PIENEMPI kuin nykyinen 93.73 us** - TAMA on ratkaiseva kriteeri,
  ei Fmax yksinaan.

Jos viimeinen kriteeri ei tayty, pipelinointi EI OLE onnistunut
optimointi taman jarjestelman kayttotapaukselle, vaikka Fmax
nousisikin - ja silloin oikea johtopaatos on sailyttaa nykyinen,
yksinkertaisempi 1-syklinen butterfly-toteutus.

## Vaihtoehto B kokeiltu: sijoitteluoptimointi ilman RTL-muutoksia

**Kayttajan oma ehdotus:** kokeile parantaako pelkka P&R-optimointi
Fmax:aa ilman RTL-muutoksia, ennen pipelinointipaatosta.

Kokeiltu (sama synteesoitu netlist koko ajan, `pnr_synth3.json`):
- `--placer sa` (oletus) vs. `--placer heap`: 21.21 MHz molemmilla.
- Neljä eri satunnaissiementa (`--seed 1/42/100/7777`): 20.92-21.37
  MHz - **vaihteluvali vain ~2%**.
- Aggressiivinen ajoitusohjattu sijoittelu
  (`--placer-heap-timingweight 50 --slack_redist_iter 10`): 21.12 MHz -
  ei parannusta.

**JOHTOPAATOS: sijoitteluoptimointi ON DE FACTO LOPPUUNKAYTETTY talle
netlistille.** Kaikki kokeillut sijoittelustrategiat (algoritmi,
siemen, ajoituspainotus) konvergoituvat samaan ~21 MHz -tulokseen
~2%:n tarkkuudella. Tama on vahva viite etta pullonkaula on
RAKENTEELLINEN (RTL:n oma logiikkasyvyys), EI sijoittelun laatu-
kysymys jonka nextpnr voisi ratkaista paremmalla algoritmilla.

**Tama tukee sita etta Vaihtoehto A (RTL-pipelining) on
TODENNAKOISESTI VALTTAMATON merkittavaan Fmax-parannukseen** - MUTTA
aiemmin todettu reititys-logiikka-jakauma (22.9ns reititys vs. 20.5ns
logiikka) tarkoittaa etta pipelinoinnin OMA hyoty riippuu MYOS siita,
kuinka hyvin nextpnr pystyy sijoittamaan LYHYEMMAT pipeline-vaiheet
(pienempi logiikka per vaihe saattaa mahdollistaa MYOS paremman
sijoittelun per vaihe, koska pienempi looginen alue voidaan sijoittaa
tiiviimmin).

## Skenaarioanalyysien luonne (kayttajan oma korjaus)

Aiemmin esitetty kannattavuustaulukko (Fmax x1.5/2.0/2.5/3.0,
+1/+2/+3 sykli/bf) on **SKENAARIOANALYYSI, EI ENNUSTE.** Taulukon
luvut riippuvat tayzin siita, kuinka monta lisasyklia todellinen
pipelinointi vaatii ja kuinka paljon Fmax todella nousee - naita EI
VIELA TIEDETA, ne pitaa MITATA toteutuksen jalkeen. Taulukko on
tarkoitettu havainnollistamaan PAATOKSENTEON LOGIIKKAA (miksi pelkka
Fmax ei riita), ei ennustamaan lopputulosta.

## M4-FPGA-007 koe: yksi rekisterivaihe (kayttajan oma, tarkasti rajattu ehdotus)

**Toteutus:** uusi tila `S_COMPUTE1` lisatty `lane_fsm`:aan (eristetty
tutkimusprototyyppi, `fpga/timing_reports/pqc_rvv_cluster_2lane_1stage_pipeline.sv`).
Katkaisee kolmen kertolaskun ketjun: Vaihe 1 laskee ENSIMMAISEN
kertolaskun (`b_reg*zeta_in` FORWARD:lle, `(b-a)*zeta_in` INVERSE:lle)
ja REKISTEROI sen (`mult_term`). Vaihe 2 (entinen `S_COMPUTE`) kayttaa
rekisteroitua `mult_term`:ia Montgomery-redusointiin + lopulliseen
yhteen-/vahennyslaskuun.

**Todennettu ensin (kayttajan oma jarjestys):**
1. Golden trace (koko 7-tasoinen ajo, pipelinoitu vs. alkuperainen):
   **PASS, kaikki 64 tasoa tasmaavat taydellisesti.**
2. Syklimaara: **2436** (perustaso 1988 + 448 = tasmaa TARKALLEEN
   +1 sykli/lane-iteraatio -odotukseen).
3. Synteesi: **DP16KD=4 sailyi.**
4. Uusi P&R-ajo samalla LFE5U-25F-kohteella.

## TULOSTAULUKKO: mitattu, ei arvioitu

| Mittari | Perustaso (0 pipeline-vaihetta) | 1 pipeline-vaihe | Muutos |
|---|---|---|---|
| Fmax | 21.21 MHz | **30.40 MHz** | **1.43x** |
| Sykliä/NTT | 1988 | 2436 | 1.23x |
| **us/NTT (lapimenoaika)** | **93.73 us** | **80.13 us** | **-14.5% (parannus)** |
| DP16KD | 4 | 4 | ei muutosta |
| Kriittinen polku | butterfly-aritmetiikka (bp_reg, 3 ketjutettua kertolaskua) | **DP16KD:n oma lukurekisteri (core.bank3)** | vaihtui |

**TULOS: MITATTU NETTOPARANNUS +14.5% lapimenoajassa yhdella ainoalla
rekisterivaiheella.** Tama tasmaa lahella aiempaa skenaarioanalyysin
"+1 sykli/bf, Fmax x1.5" -riviä (arvioitu +18%, toteutunut +14.5%) -
skenaarioanalyysin metodologia osoittautui kohtuullisen tarkaksi
tallä kertaa, vaikka se oli tarkoitettu vain paatoksentekologiikan
havainnollistamiseen, ei ennusteeksi.

## Uusi kriittinen polku: DP16KD:n oma lukurekisteri

Pipelinoinnin jalkeen kriittinen polku SIIRTYI aritmetiikasta
`core.bank3`:n omaan lukurekisteriin (`DOB5`-signaali, DP16KD:n oma
data-out-portti) - 5.2 ns logiikkaa, 13.3 ns reititysta (yhteensa
18.5 ns, paljon lyhyempi kuin aiempi 43.4 ns).

Tama on ODOTETTU, TERVETULLUT ilmio: yhden pullonkaulan poistaminen
paljasti SEURAAVAN, PIENEMMAN pullonkaulan (BRAM:n oma ajoitus) -
tama on tyypillinen iteroivan optimoinnin kuvio. BRAM:n oma
lukuviive on todennakoisesti lahella ECP5:n DP16KD:n omaa
fyysista rajaa taalla koolla/konfiguraatiolla - lisaoptimointi
vaatisi todennakoisesti BRAM:n oman lukupolun (esim. ylimaarainen
pipeline-rekisteri BRAM-ulostulon jalkeen) tarkastelua, JOKA ON
OMA, ERILLINEN seuraava tutkimuskysymyksensa.

## Johtopaatos

**Yhden rekisterivaiheen koe oli MENESTYS mitatun kriteerin
(lapimenoaika) mukaan: +14.5% parannus.** Kayttajan oma metodologia
(rajattu koe, mittaa objektiivisesti ENNEN suurempaa investointia)
todistautui oikeaksi lahestymistavaksi - pieni, kohdennettu muutos
antoi mitattavan, positiivisen tuloksen ilman etta koko butterflyn
tarvinnut uudelleensuunnitella.

**Ei viela paatosta jatkotoimista tuotantoytimeen integroinnista** -
tama on edelleen tutkimusprototyyppi (`fpga/timing_reports/`-
hakemistossa). Mahdollinen seuraava askel (jos halutaan jatkaa):
sama menetelma toistettuna BRAM:n omalle lukuviiveelle, TAI paatos
etta +14.5% on jo riittava parannus taman tyopaketin tarpeisiin.

## Uuden kriittisen polun tarkka luonne (M4-FPGA-006A:n jatkotutkimus)

**Kayttajan oma kysymys:** onko uusi pullonkaula (1) DP16KD:n oma
rekisteriviive, (2) sen ymparilla oleva ohjauslogiikka, vai (3)
BRAM->DSP-reititys?

**Tarkka polkujaljitys (koko ketju alusta loppuun) paljastaa
vastauksen: (2) - OMA ARBITROINTILOGIIKKAMME, EI DP16KD:n oma
sisainen viive.**

Signaalinimet polun alkupaassa: `core.bank3.0.0_ADA9_PFUMX_C0_Z_
L6MUX21_Z_D1_L6MUX21_Z_D1_PFUMX_Z_...` - tama on USEAN TASON LUT-
pohjainen multipleksointiketju (PFUMX, L6MUX21 - molemmat ECP5:n
omia LUT-yhdistelmaprimitiiveja) joka laskee OSOITTEEN ("ADA9" =
osoitebitti 9) DP16KD:n omaan osoiteporttiin - EI itse muistin
sisainen lukuviive.

**Tama on M4-FPGA-004:n oma lukuarbitrointilogiikka**
(`shared_raddr0-3`-laskenta, toteutettu `for (int tb=0;tb<4;tb++)`
-silmukalla ja sisakkaisilla if-else-ketjuilla tarkistamaan
`pb_a0==tb`, `pb_b0==tb` jne.) - tama LUONNOLLISESTI synteesoituu
usean LUT-tason prioriteettiketjuksi, joka nyt on kriittisin polku
kun aritmetiikka on jo pipelinoitu.

## Johtopaatos: pullonkaula on OMAA logiikkaamme, ei kiintea rajoite

Tama on itse asiassa HYVA UUTINEN: koska kyseessa on OMA arbitrointi-
logiikkamme (ei DP16KD:n oma, muuttumaton fyysinen rajoite), on
todennakoista etta LISAOPTIMOINTI VOI VIELA AUTTAA - esimerkiksi:
1. Rekisteroida `shared_raddr0-3` YHDEN SYKLIN ennen kuin niita
   kaytetaan DP16KD:n osoitteena (siirtaa arbitroinnin OMA logiikka
   pois kriittiselta polulta, DP16KD:n oma luku seuraisi sitten
   PUHTAASTI rekisteroitua osoitetta).
2. Yksinkertaistaa arbitrointilogiikkaa (esim. korvata sisakkainen
   if-else-ketju tasaisemmalla, rinnakkaisemmalla prioriteetti-
   enkooderilla).

**Tama TUKEE kayttajan omaa varovaista nakemysta:** koska pullonkaula
EI OLE itse muistilohkon kiintea ominaisuus, lisapipelinointi
TODENNAKOISESTI VOISI VIELA TUOTTAA HYOTYA - toisin kuin jos kyseessa
olisi ollut DP16KD:n oma, muuttumaton fyysinen raja.

**Ei viela toteutettu eika mitattu** - tama vaatisi OMAN, uuden,
tarkasti rajatun kokeensa (sama menetelma kuin M4-FPGA-007:ssa)
ennen paatoksentekoa.

## M4-FPGA-006B koe: osoitteen rekisterointi - REHELLINEN NEGATIIVINEN TULOS

**Toteutus:** rekisteroitu `shared_raddr0-3` (lukuarbitroinnin oma
osoite) YHDEN SYKLIN ennen kayttoa BRAM:n osoitteena - uusi
`S_WAIT_READ2`-tila lisatty (tutkimusprototyyppi,
`pqc_rvv_cluster_2lane_addr_pipeline.sv` +
`pqc_ntt_stage_banked_addr_pipe.sv`).

**Todennettu ensin (sama jarjestys kuin M4-FPGA-007):**
1. Golden trace: PASS, kaikki 64 tasoa tasmaavat.
2. Bring-up-luku (2-syklinen viive synkronoitu): PASS 20/20.
3. Syklimaara: **2884** (tasmaa tarkalleen "+2 sykli/bf"-skenaarioon:
   1988 + 2x448 = 2884).
4. DP16KD=4 sailyi synteesissa.

## TULOSTAULUKKO

| Mittari | 1 pipeline-vaihe (M4-FPGA-007) | + osoitteen rekisterointi | Muutos |
|---|---|---|---|
| Fmax | 30.40 MHz | 30.46 MHz | **+0.2% (ei merkittava)** |
| Sykliä/NTT | 2436 | 2884 | 1.18x |
| **us/NTT** | **80.13** | **94.68** | **-18.2% (HUONONTUU)** |
| DP16KD | 4 | 4 | ei muutosta |

**TULOS: NETTOTULOS ON HUONOMPI kuin 1-vaiheinen pipeline.**
Osoitteen rekisterointi lisasi yhden sykliin per iteraatio ilman
merkittavaa Fmax-hyotya.

## Selitys: kaksi lahes yhta pitkaa polkua kilpailivat

Uuden P&R-ajon kriittinen polku EI OLLUT enaa BRAM-osoite - se
palasi `core.lane0.bp_reg`:iin (aritmetiikka, sisaltaa `CCU2C`-
carry-chain-yksikoita) - **17.3 ns logiikkaa, 15.6 ns reititysta**
(32.9 ns yhteensa, ~30.4 MHz).

**Tama paljastaa: M4-FPGA-007:n oma 1-vaiheinen pipeline JATTI
JALJELLE toisen, LAHES YHTA PITKAN polun** (montgomery_reduce:n
OMAT KAKSI jaljella olevaa kertolaskua, jotka eivat viela olleet
pipelinoituja) - taman polun pituus oli aiemmin VAIN HIEMAN lyhyempi
kuin BRAM-osoitepolku (joka nayttaytyi silloin kriittisena), mutta
KUN BRAM-osoitepolku KORJATTIIN (rekisteroitiin), aritmetiikkapolku
NOUSI TAKAISIN kriittiseksi - JA sen oma pituus ei ollut riittavasti
lyhyempi etta kokonaisFmax olisi noussut.

**JOHTOPAATOS: BRAM-osoitteen rekisterointi YKSINAAN ei riita, koska
kaksi lahes yhta pitkaa pullonkaulaa (BRAM-osoite JA jaljella oleva
Montgomery-kertolaskuketju) rajoittavat vuorotellen.** Molemmat
tarvitsisivat samanaikaisen kasittelyn (esim. lisata TOINEN
aritmeettinen pipeline-vaihe montgomery_reduce:n kahden jaljella
olevan kertolaskun valiin, YHDESSA BRAM-osoitteen rekisteroinnin
kanssa) jotta kumpikaan ei olisi enaa hallitseva.

## Kayttajan oma hyvaksymiskriteeri toteutui: rehellinen mittaus

Tama on TASMALLEEN se tulos jonka kayttaja ennakoi mahdolliseksi:
"jos pullonkaula on itse muistilohkon ominaisuus, lisapipelining
ei ehka enaa tuo yhta suurta hyotya". Tassa TAPAUKSESSA sita EI OLLUT
DP16KD:n oma kiintea rajoite (kuten aiemmin todettiin), MUTTA silti
tama YKSITTAINEN lisays ei riittanyt - koska JOKIN MUU (aritmetiikka)
oli LAHES yhta pitka pullonkaula.

**Tama koe HYLATAAN nettotuloksen (-18.2%) perusteella.** M4-FPGA-007:n
1-vaiheinen versio (Fmax=30.40MHz, 80.13us/NTT) pysyy PARHAANA
mitattuna tuloksena taman tutkimuksen aikana.
