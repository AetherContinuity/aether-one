# M4_FPGA_BRINGUP_NOTE.md — M4-FPGA-001: bring-up ja synteesikelpoisuus

**Päivämäärä:** 2026-07-14
**Tila:** VALMIS (rajattu tavoite, ks. alla)

## Tavoite

Todistaa etta NTT-ytimen (`pqc_ntt_stage_banked.sv`) sisainen tila
(muistipankit bank0-3) voidaan ankkuroida FPGA-synteesiin **ilman
muutoksia laskentalogiikkaan** (butterfly, FSM, osoitelaskenta, NTT-
operaatiot).

## Suunnitteluperiaate (kirjattu talteen M4:n alkuun)

> Production RTL remains bus-agnostic. FPGA wrappers expose
> implementation-specific interfaces (load/read/control) without
> modifying the verified cryptographic core.

## Lahtotilanne: havaittu ongelma

`pqc_ntt_stage_banked.sv`:n bank0-3-muistitaulukot ovat puhtaasti
sisaisia (ei porttitason nakyvyytta). Kun moduuli synteesoitiin
YKSINAAN ECP5-kohteelle (Yosys `synth_ecp5`), synteesi paatteli
OIKEIN etta koska mikaan porttitason signaali ei koskaan lataa
alkuarvoja pankkeihin eika lue niiden lopullista sisaltoa ulos, koko
pankkilogiikka on havaitsematon moduulin oman rajapinnan nakokulmasta
- ja optimoitui pois kokonaan (`Number of memories: 0`, vain 287
solua = pelkkaa ohjauslogiikkaa).

Tama EI ollut synteesivirhe eika RTL-bugi - se oli hyodyllinen
havainto siita etta testausrajapinta (testipenkkien hierarkkinen
`dut.bank0[i]`-pikäsy) ja synteesirajapinta ovat eri asioita.

## Kokeillut, EIVAT toimineet ratkaisut (dokumentoitu ettei niita
tarvitse kokeilla uudelleen)

1. **Hierarkkinen viittaus** wrapper-moduulista ytimen instanssiin
   (`core.bank0[addr]`): Yosys tulkitsi taman IMPLISIITTISESTI
   UUDEKSI, TAYSIN IRRALLISEKSI langaksi ("used but has no driver"),
   ei viittaukseksi todelliseen instanssin sisaiseen tilaan. EI
   TOIMI Yosysin nykyisella SystemVerilog-tuella.

2. **SystemVerilogin `bind`-rakenne**: sama ongelma - kohdemoduulin
   sisainen signaali tulkittiin "implisiittisesti julistetuksi", ei
   oikeaksi viittaukseksi. EI TOIMI.

## Toteutettu ratkaisu: eksplisiittiset bring-up-portit

Lisatty `pqc_ntt_stage_banked.sv`:aan VALINNAINEN `FPGA_BRINGUP`-
parametri (oletus `1'b0` - EI vaikuta olemassa olevaan kayttoon
lainkaan) ja portit:

```
input  logic load_valid,
input  logic [7:0] load_addr,
input  logic [COEFF_W-1:0] load_data,
input  logic read_en,
input  logic [7:0] read_addr,
output logic read_valid,
output logic [COEFF_W-1:0] read_data
```

Kaikki bring-up-logiikka on `generate if (FPGA_BRINGUP)`-lohkon
sisalla - kun `FPGA_BRINGUP=0` (oletus), koko lohko synteesoituu
pois, taysin identtisesti aiempaan nahden. Uudelleenkayttaa jo
olemassa olevaa, muodollisesti todistettua `bank_rom`/`local_rom`-
osoitekartoitusta - EI uutta kryptografista logiikkaa.

Kaikki 21 olemassa olevaa testipenkkia paivitetty kytkemaan uudet
portit passiivisiksi (`load_valid=0, read_en=0` jne.) - taysin
neutraali muutos niiden nakokulmasta.

## Todennus (regressio muuttumattomuudesta)

Ajettu TAYDELLINEN M3-regressio uudelleen porttimuutoksen jalkeen:

1. Golden-mallin 1000-syotteen regressio: PASS
2. K-PKE.KeyGen->Encrypt->Decrypt->m round-trip: PASS
3. ML-KEM.Decaps_internal TB A+B (FO-hylkays mukaan lukien): PASS
4. K-PKE.KeyGen 10x samassa simulaatiossa: PASS
5. Jaadytettyjen referenssien eheystarkistus (4 tiedostoa): PASS,
   EI MUUTOKSIA vectors/-hakemistossa
6. FIPS203_COVERAGE.md-kattavuustarkistus: PASS
7. Verilator-lint (LATCH/UNDRIVEN/COMBDLY): 0 loydosta
8. Yosys ECP5-synteesi, `FPGA_BRINGUP=0` (oletus): **287 solua,
   TASMALLEEN sama kuin ennen porttimuutosta** - todistaa etta
   oletuskaytos ei muuttunut.

## Havainto (M4-FPGA-001): rekisterointi ei riittanyt BRAM-inferointiin

`FPGA_BRINGUP=1`:lla, kombinatorinen `read_data`-toteutus (ensimmainen
yritys) johti solumaaran rajuun kasvuun (287 -> 97057 solua, 256-tien
kombinatorinen mux-verkko) - pankit tulivat havaittaviksi (ei enaa
optimoitu pois), mutta erittain tehottomasti.

Korjattu REKISTEROITYYN lukupolkuun (`read_en`/`read_addr` ->
1 syklin viive -> `read_valid`+`read_data`, standardi synkronisen
muistin lukukuvio). Tulos: solumaara pysyi lahes samana (95477),
`Number of memories: 0` SAILYI. `local_rom` nakyi edelleen
"Replacing memory"-varoituksessa; `bank0-3` eivat enaa esiintyneet
listassa nimeltamainittuina, mutta eivat silti inferoituneet
DP16KD (ECP5:n EBR-primitiivi) -soluiksi - vain hiljaa rekistereiksi.

**Johtopaatos: rekisterointi yksinaan EI riittanyt automaattiseen
ECP5 BRAM-inferointiin.** Sisainen muisti tuli havaittavaksi synteesille
(estaen kuolleen koodin poiston), mutta Yosys toteutti sen edelleen
hajautettuna logiikkana, ei DP16KD-lohkoina. Todennakoisin syy:
NELJA ERILLISTA pankkitaulukkoa + ulkoinen ROM-pohjainen pankinvalinta
ei vastaa Yosysin `memory_bram`-vaiheen odottamaa yksinkertaista,
yhtenaisen muistin osoitedekoodauskuviota.

**Tama on eri tutkimuskysymys kuin bring-up**, ja siirretty omaksi
tyopaketikseen M4-FPGA-002:een (ks. alla).

## M4-FPGA-001:n onnistumiskriteerit (TAYTETTY)

- [x] NTT-ytimen sisainen tila ei enaa optimoidu pois synteesissa.
- [x] `FPGA_BRINGUP=0` sailyttaa taysin aiemman kayttaytymisen
      (regressio vihrea, solumaara identtinen).
- [x] `FPGA_BRINGUP=1` tekee muistipankit synteesin nakokulmasta
      havaittaviksi.
- [x] Laskentalogiikka (butterfly, FSM, osoitelaskenta, NTT-operaatiot)
      ei muuttunut lainkaan.
- [x] Kaikki M3-regressiot pysyvat PASS.

## Jaljella: M4-FPGA-002 (oma tyopaketti, EI viela aloitettu)

Tutkimuskysymys: "Miten tama muistirakenne saadaan inferoitumaan
ECP5 EBR:ksi?" - ei liity ML-KEM:iin, NTT:hen tai kryptografiseen
oikeellisuuteen, puhtaasti FPGA-arkkitehtuurin optimointia.

Vaihtoehdot vertailtavaksi:
1. Yksi yhtenainen RAM (`coeff_mem[0:255]`), pankitus osoitteella
   erillisen 4-taulukko-rakenteen sijaan.
2. Nelja RAM-instanssia kayttaen ECP5:n omia primitiiveja suoraan.
3. Yosys-attribuutit (esim. `(* ram_style = ... *)` tai vastaavat
   `memory_bram`-ohjaukset).
4. Suora `DP16KD`-instansiointi, jos inferointi osoittautuu
   epaluotettavaksi.

Vasta taman jalkeen mielekkaat ECP5-resurssiluvut (LUT/FF/BRAM,
Fmax, nextpnr-ecp5:n place & route, ajoitusraportti) voidaan koota.
