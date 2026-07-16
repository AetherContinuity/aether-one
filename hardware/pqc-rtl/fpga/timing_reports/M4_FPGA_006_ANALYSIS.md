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
