# M4-SoC-001: Wishbone-vaylakaare - VALMIS

**Paivamaara:** 2026-07-19
**Tila:** TUTKIMUSPROTOTYYPPI, TOIMII - PASS koko 7-tasoinen NTT
puhtaasti Wishbone-vaylan kautta.

## Tavoite

Rakentaa ohut Wishbone B4 -tyyppinen vaylakaare
`pqc_ntt_stage_banked`-ytimelle, kayttaen jo olemassa olevaa bring-up-
rajapintaa (M4-FPGA-001) - EI muutoksia itse ytimeen.

## Loydetty ja korjattu bugi: kadonnut yhden syklin pulssi

**Alkuperainen ongelma:** `stage_done` on ytimen oma YHDEN SYKLIN
pulssi (palautuu 0:aan valittomasti kun FSM palaa `S_IDLE`:en).
Wishbone-status-kysely vaatii USEITA sykleja per luku (kattelyn
takia: osoite -> stb/cyc -> odota ack -> deassert). Talla valilla
ehtii kulua monta sykliä - jos `stage_done` pulssaa JUURI naiden
kahden pollausyrityksen valissa, se JAA KOKONAAN HUOMAAMATTA.

**Loydettiin delta-debuggingilla:** lisattiin hierarkkinen debug-
tulostus (`core.stage_done`, `lane0.state` jne.) suoraan simulaatioon.
Havaittiin etta FSM OLI JO PALANNUT `S_IDLE`:en (state=0) siina
vaiheessa kun status-luku aina raportoi "ei valmis" - tama todisti
etta ITSE LASKENTA toimi oikein, MUTTA status-luvun oma ajoitus
hukkasi pulssin systemaattisesti.

**Korjaus:** TARRAAVA (sticky) status-bitti - `stage_done_sticky`
asetetaan 1:ksi heti kun `stage_done` pulssaa, ja PYSYY 1:sena
kunnes ohjelmisto EKSPLISIITTISESTI tyhjentaa sen (uuden `start`-
kirjoituksen yhteydessa, mika vastaa luonnollista kayttotarvetta:
lue edellisen operaation status ENNEN seuraavan kaynnistysta).

## Tulos

**PASS: koko 7-tasoinen ML-KEM-512-NTT ajettu KOKONAAN Wishbone-
vaylan kautta** (256 alkuarvon kirjoitus + 64 CTRL/status-sykliä per
taso + 256 tuloksen luku), tasmaa golden-malliin taydellisesti.

## Osoitekartta (lopullinen)

| Osoite | Nimi | Kuvaus |
|---|---|---|
| 0x000-0x0FF | DATA | Kertoimen luku/kirjoitus (bring-up) |
| 0x100 | CTRL | [0]=start (kirjoitus laukaisee pulssin + tyhjentaa statuksen), [1]=mode |
| 0x101 | COUNT | |
| 0x102 | PAIR_DIST | |
| 0x103 | BASE_ADDR_LANE0 | |
| 0x104 | BASE_ADDR_LANE1 | |
| 0x105 | ZETA_LANE0 | |
| 0x106 | ZETA_LANE1 | |
| 0x107 | STATUS (luku) | [0]=stage_done (sticky), [1]=bank_conflict_detected (sticky) |

## Rajaukset (dokumentoitu, ei viela ratkaistu)

- **Datavayla vain 16 bittia leveys** (COEFF_W) - tuotantokelpoinen
  SoC-integraatio (esim. 32-bit AXI-Lite) on oma, myohempi tyonsa.
- **Ei viela synteesitestattu ECP5:lla** - tama koe oli puhtaasti
  toiminnallinen (simulaatio), ei viela P&R-vahvistettu.
- **Ei viela tuotantointegraatiota** - pysyy tutkimusprototyyppina
  `fpga/`-hakemistossa.
