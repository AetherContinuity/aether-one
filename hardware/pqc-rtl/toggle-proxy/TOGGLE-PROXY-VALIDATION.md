# Toggle-count-proxy: mittarin validointi tunnetulla vuodolla

**Tila:** validoitu 2026-07-22. Mittari LAPAISI seka positiivi- etta
negatiivikontrollin. EI VIELA sovellettu Decapsiin - se on erillinen,
seuraava askel (ks. M3-MLKEM-002-encaps-decaps-plan.md:n oma
edellytys).

## Menetelma

Kaksi leikkitoteutusta, SAMAT syotteet, RINNAKKAIN samassa
simulaatiossa:
- `toy_leaky_compare.sv`: 32-tavuinen vertailu VARHAISELLA
  keskeytyksella (tunnetusti vuotava, positiivikontrolli).
- `toy_constant_compare.sv`: sama vertailu YHTENA leveana
  `===`-lausekkeena (sama rakenne kuin ML-KEM:n oma, jo todettu
  syklitasolla vakioaikainen vertailu - negatiivikontrolli).

Neljä tapausta: eroaa tavussa 0 (aikaisin), tavussa 15 (keskella),
tavussa 31 (myohaisin), tai ei eroa lainkaan (taysi skannaus).

`count_toggles.py`: minimaalinen VCD-jasennin joka laskee arvon-
vaihtumien maaran per moduulihierarkia (`dut_leaky` / `dut_const`).

**HUOM tulkinnassa:** `clk`/`reset`/`start`/`a_in`/`b_in` jakavat
saman VCD-tunnisteen molempien moduulien kesken (Icarus ei
dupliloi pass-through-signaaleja) - naita EI kayteta vertailussa,
koska ne heijastavat testipenkin OMAA kokonaiskestoa (rajoittuu
hitaamman moduulin mukaan), EI moduulikohtaista aktiivisuutta.
Tulkinta rajattu SISAISIIN/ulostulosignaaleihin (`state`, `idx`,
`cmp_stage_out`, `done`, `match_out`).

## Tulokset

### Positiivikontrolli (`toy_leaky_compare`, `idx`-laskurin kytkennat)

| mismatch_pos | idx-kytkennat |
|---|---|
| 0 (aikaisin) | 2 |
| 15 (keskella) | 17 |
| 31 (myohaisin) | 33 |
| ei eroa (taysi skannaus) | 33 |

Tasan monotoninen suhde vuotoaseman ja kytkentamaaran valilla -
MITTARI NAKEE TUNNETUN VUODON.

### Negatiivikontrolli (`toy_constant_compare`, `state`/`done`-kytkennat)

| mismatch_pos | state-kytkennat | done-kytkennat |
|---|---|---|
| 0 | 5 | 4 |
| 15 | 5 | 4 |
| 31 | 5 | 4 |
| ei eroa | 5 | 4 |

TASAN SAMAT kaikissa neljassa tapauksessa - MITTARI EI NAYTA VUOTOA
JOSSA SITA EI OLE.

## Johtopaatos

Toggle-count-proxy-menetelma (VCD-dumppaus + kytkentalaskenta,
rajattuna moduulin sisaisiin/ulostulosignaaleihin, pois lukien
jaetut pass-through-tulot) LAPAISI seka positiivi- etta
negatiivikontrollin selvasti erottuvalla tuloksella. Tama TAYTTAA
M3-MLKEM-002-suunnitelman oman edellytyksen ("todista ETTA mittari
nakee tunnetun vian, VASTA SITTEN vaita ettei vikaa OLE kohteessa")
- mittari on nyt VALIDOITU taman kapean testiasetelman puitteissa.

**EI VIELA sovellettu Decapsiin.** Tama on seuraava, erillinen askel.
