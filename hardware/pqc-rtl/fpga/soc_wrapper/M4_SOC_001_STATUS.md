# M4-SoC-001: Wishbone-vaylakaare - kesken, tunnettu bugi

**Paivamaara:** 2026-07-19
**Tila:** TUTKIMUSPROTOTYYPPI, EI VIELA toimiva - tunnettu, viela
korjaamaton toiminnallinen virhe.

## Tavoite

Rakentaa ohut Wishbone B4 -tyyppinen vaylakaare
`pqc_ntt_stage_banked`-ytimelle, kayttaen jo olemassa olevaa bring-up-
rajapintaa (M4-FPGA-001) vakioidun vaylaprotokollan takana - EI
muutoksia itse ytimeen.

## Havaittu ongelma

Testi (`pqc_ntt_wishbone_tb.sv`) kirjoittaa kaikki 256 alkuarvoa
Wishbone-kirjoituksilla (TOIMII OIKEIN), sitten ajaa koko 7-tasoisen
NTT:n ohjausrekistereiden (CTRL/COUNT/PAIR_DIST/BASE_ADDR/ZETA)
kautta.

**Taso 6 nayttaa suoriutuvan** (debug vahvistaa etta `core.start`
pulssaa oikein ja FSM etenee tilaan S_REQ_READ 5 syklin sisalla),
MUTTA seuraava aikataulun askel (`length=64`) EI KOSKAAN raportoi
valmiiksi Wishbone-status-rekisterin kautta (`status[0]` pysyy 0:ssa
koko 5000 syklin odotusajan).

## Mahdolliset syyt (EI VIELA eroteltu)

1. Wishbone-status-luvun oma ajoitusvirhe (`ctrl_read_data`-rekisterin
   paivityslogiikka voi olla virheellinen useamman perakkaisen luvun
   yli).
2. Ohjausrekisterien (COUNT/PAIR_DIST/BASE_ADDR/ZETA) kirjoitus-
   sekvenssin oma ajoitus - mahdollisesti uusi "start"-kirjoitus
   tapahtuu ENNEN kuin edellisen tason oma "done"-tila on ehtinyt
   kunnolla nollaantua FSM:n S_IDLE-tilassa.
3. `read_en`/`load_valid`-ristikytkenta status-luvun JA datan
   luvun/kirjoituksen valilla (molemmat kayttavat SAMAA fyysista
   bring-up-porttia ytimen sisalla) - Wishbone-wrapperin oma
   osoitedekoodauslogiikka (`is_data_range`/`is_ctrl_range`) VOI
   sisaltaa virheen joka aiheuttaa tahattoman read_en-aktivoinnin.

## Ei viela ratkaistu

Tama on TIETOISESTI jatettu KORJAAMATTA tassa istunnossa - ongelma
vaatii oman, kohdennetun debug-kierroksensa (esim. sama delta-
debugging-menetelma kuin M4-FPGA-003A:ssa: rakenna minimaalisin
mahdollinen Wishbone-syklikoe joka toistaa virheen, tai vertaile
aaltomuotoja hierarkkisesti dut.core:n omien signaalien ja Wishbone-
tilakoneen valilla).

**Tuotantoydin (`rtl/pqc_ntt_stage_banked.sv`) ON TAYSIN koskematon
tassa tyossa** - kaikki M3/M4-regressiot pysyvat validoituina. Tama
on puhtaasti UUDEN, viela keskeneraisen vaylakaareen oma bugi.
