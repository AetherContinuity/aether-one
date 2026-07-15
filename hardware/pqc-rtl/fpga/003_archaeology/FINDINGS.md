# M4-FPGA-003: Memory inference archaeology - white-box tulokset

**Menetelma:** Yosysin oma `debug memory_bram`/`memory_dff`-diagnostiikka,
ei enaa musta laatikko - katsottu TARKALLEEN miksi kukin lukuportti
hylataan.

## Loydos 1: alkuperainen rakenne

`memory_dff`-vaihe raportoi JOKAISELLE pankille (bank0-3) ja JOKAISELLE
niiden 5 "portille" jompikumpi:
- "no output FF found" (bank0,1,2)
- "FF found, but with a mux select that doesn't seem to correspond
  to transparency logic" (bank3)

**Juurisyy loytyi:** alkuperainen koodi kirjoittaa YHTEEN JAETTUUN
rekisteriin (esim. `rdata_a0`) `case`-valinnalla NELJASTA eri
pankista. Yosysin `memory_dff` ei tunnista tata minkaan YKSITTAISEN
pankin omaksi, puhtaaksi lukuportin rekisteriksi, koska rekisterin
arvo riippuu KAIKISTA neljasta pankista valitsimen kautta - ei
puhtaasti YHDEN muistin omasta luvusta.

## Loydos 2: mux-vasta-rekisteroinnin-jalkeen -korjaus

Rakennettu vaihtoehtoinen koodaustapa (`003_mux_after_register.sv`):
JOKAINEN pankki saa OMAN dedikoidun rekisterinsa jokaiselle osoitteelle
(paivittyy JOKA sykli riippumatta valitsimesta), ja lopullinen data
valitaan NAISTA JO REKISTEROIDYISTA arvoista vasta MYOHEMMIN
kombinatorisesti.

**Tulos: 16/19 lukuporttitarkistusta onnistui** ("merging output FF
to cell"), vain 3 jaljella (bank0[0], bank1[0], bank2[0] - bank3
onnistuu jo TAYSIN). Loput 6 "epaonnistumista" koskevat `bank_rom`:ia,
joka on TARKOITUKSELLA pieni (512 bittia) kombinatorinen osoite-
kartoitus - EI ole tarkoitus olla BRAM, tama on odotettu eika
ongelma.

## Jaljella oleva, kavennettu kysymys

Miksi `bank0[0]`, `bank1[0]`, `bank2[0]` (mutta EI `bank3[0]`) yha
epaonnistuvat "no output FF found"? Todennakoinen ehdokas: kirjoitus-
portin oma read-before-write-lapinakyvyystarkistus (DP16KD:n oma
rdwr-semantiikka, ks. /usr/share/yosys/ecp5/brams.txt: "rdwr
no_change/new/old") - koska bank3:n oma kirjoitus (`default:` case-
haara) saattaa saada eri kohtelun Yosysin analyysissa kuin eksplisiit-
tiset `2'd0/1/2`-haarat.

## Ei viela ratkaisua, mutta merkittava kavennus

Tama on ERITTAIN merkittava kavennus: alkuperaisesta "0/20 onnistui"
-tilanteesta paastiin "16/19 onnistuu, 3 jaljella (kaikki liittyvat
kirjoitusportin transparenssiin, ei enaa lukuporttien omaan
rekisterointiin)". Seuraava askel: tutkia TASMALLEEN mika
kirjoitusportin rakenteellinen ero bank3:n ja bank0-2:n valilla
selittaa taman viimeisen eron.

## Lisatutkimus 2026-07-18: RTLIL-vertailu bank0 vs bank3

**Kayttajan oma ehdotus:** vertaile RTLIL-tasolla miksi bank3 onnistuu
mutta bank0-2 eivat.

`write_rtlil`-dumpista loytyi rakenteellinen ero: bank0:n oma
`$memrd`-solmu esiintyy YHDISTETYSSA `connect \B { bank0, bank1,
bank2 }` -rakenteessa, kun taas bank3:n oma on YKSINAINEN, itsenainen
`connect \A`. Tama viittasi siihen etta `case`-lauseen `default:`-
haara (bank3) kasitellaan rakenteellisesti eri tavalla kuin
eksplisiittiset `2'd0/1/2`-haarat.

**Testattu hypoteesi:** korvattu `default:` eksplisiittisella
`2'd3:`:lla (`003b_explicit_case.sv`). **Tulos: EI muutosta** - sama
kolmen epaonnistumisen kuvio (bank0/1/2:n "portti[0]") sailyi
ENNALLAAN. Bank3:n oma "portti[0]" EI enaa edes esiintynyt listassa
(luultavasti optimoitui pois trivialisti eri tavalla).

**Tarkennettu tulkinta "portti[0]":sta:** todennakoisesti tama VIITTAA
kirjoitusportin omaan read-before-write-lapinakyvyystarkistukseen
(DP16KD:n oma rdwr-semantiikka), EI erilliseen lukukanavaan - koska
lukukanavia on vain 4 (a0,b0,a1,b1) mutta "portteja" tarkistetaan 5.
Bank3:n kirjoituspolku nayttaa saavan jostain (viela tunnistamattomasta)
syysta erilaisen, Yosysille helpommin ratkeavan rakenteen kuin
bank0-2:n omat.

**Ei viela lopullista vastausta.** `default` vs. eksplisiittinen
case EI ollut selittava tekija - juurisyy on jotain hienovaraisempaa
kirjoitusportin transparenssilogiikassa, tarkentumatta viela taman
kierroksen aikana.
