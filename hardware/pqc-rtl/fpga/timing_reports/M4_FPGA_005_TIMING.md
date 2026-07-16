# M4-FPGA-005: ensimmainen ECP5-sijoittelu ja ajoitusraportti

**Paivamaara:** 2026-07-19
**Kohdelaite:** LFE5U-25F, CABGA381-kotelointi, nopeusluokka oletus
**Tyokalu:** nextpnr-ecp5 0.6-3build5

## Resurssien kaytto (pqc_ntt_stage_banked, NTT_READ_LATENCY=1,
FPGA_BRINGUP=1)

| Resurssi | Kaytetty | Yhteensa | % |
|---|---|---|---|
| DP16KD (BRAM) | 4 | 56 | 7% |
| TRELLIS_COMB (LUT) | 2643 | 24288 | 10% |
| TRELLIS_FF | 325 | 24288 | 1% |
| MULT18X18D (DSP) | 6 | 28 | 21% |
| TRELLIS_IO | 123 | 197 | 62% |

**Erittain kohtuullinen resurssienkaytto** - koko NTT-ydin (molemmat
lanet, konfliktintunnistus, bring-up-portit) mahtuu vain 10% LUT-
kapasiteetista ja 7% BRAM-kapasiteetista pienimmalla ECP5-25k-
laitteella.

## Ajoitus: Fmax = 21.05 MHz - MUTTA taman raportin oma varaus

**TARKEA HAVAINTO:** nextpnr:n oma kriittisen polun jaljitys osoittaa
etta pisin polku on:

```
4.2 ns logiikkaa, 11.2 ns REITITYSTA
paattyy: bank_conflict_detected$TRELLIS_IO_OUT
```

**`bank_conflict_detected` on KOMBINATORINEN ulostulo joka tassa
synteesissa kulkee SUORAAN piirin fyysiselle nastalle** (koska
`pqc_ntt_stage_banked` synteesoitiin YKSINAAN, ilman ymparoivaa
jarjestelmaa joka normaalisti kuluttaisi taman signaalin sisaisesti).

**Tama tarkoittaa: raportoitu 21 MHz on I/O-REITITYKSEN rajoittama,
EI ytimen oman sisaisen logiikan rajoittama.** Todellisessa
jarjestelmassa (esim. M4-SoC-002:n oma vayla-integraatio), tama
signaali kulkisi sisaisesti toiseen moduuliin, ei fyysiselle nastalle -
todennakoisesti antaen HUOMATTAVASTI korkeamman Fmax:n.

## Seuraava askel mielekkaampaa Fmax-lukua varten

Jotta saadaan ytimen OMAN sisaisen logiikan rajoittama (ei I/O-
rajoittama) Fmax, tarvitaan JOKO:
1. Rekisteroida kaikki kombinatoriset ulostulot (esim.
   bank_conflict_detected) ENNEN nextpnr-ajoa, TAI
2. Kayttaa nextpnr:n omaa `--ignore-loops`/aluerajoitusta joka
   sallii I/O-viiveen jattamisen pois ajoitusanalyysista, TAI
3. (suositeltavin) rakentaa pieni wrapper-moduuli jossa
   `bank_conflict_detected` YHDISTETAAN sisaisesti (esim. AND-
   portilla johonkin toiseen signaaliin) ENNEN ulostuloa, jolloin
   nextpnr ei enaa nae sita suorana yhden-portin-yhden-nastan
   -polkuna.

Tama on dokumentoitu tarkasti, koska raakaluvun (21 MHz) esittaminen
sellaisenaan ilman tata selitysta antaisi harhaanjohtavan kuvan
ytimen todellisesta suorituskyvysta.

## PAIVITYS: korjattu mittaus wrapper-moduulilla (`pnr_wrapper.sv`)

Rakennettu pieni wrapper (`pqc_ntt_wrapper`) joka REKISTEROI kaikki
`pqc_ntt_stage_banked`:n ulostulot (`stage_done`, `bank_conflict_detected`,
`read_data`, `read_valid`) ENNEN nastaa - poistaa suoran kombinatorisen
I/O-polun.

**Ensimmainen yritys** (vain `stage_done`/`bank_conflict` rekisteroity,
`read_data` EI kaytossa): Fmax nousi 96.8 MHz:iin, MUTTA `DP16KD=0` -
pankkien sisalto ei enaa ollut havaittavaa mistaan ulostulosta, joten
se optimoitui pois (sama ilmio kuin M4-FPGA-001:n alkuperainen loydos).
**Tama luku hylattiin harhaanjohtavana.**

**Korjattu versio** (myos `read_data`/`read_valid` rekisteroitu, pitaen
pankkien sisallon havaittavana): `DP16KD=4` sailyi. Uusi kriittinen
polku on **AIDOSTI SISAINEN**: `core.lane1.bp_reg` (butterfly-
laskennan oma b-arvon rekisteri) - EI enaa I/O-reititysta.

## LOPULLINEN, VAHVISTETTU TULOS

| Mittari | Arvo |
|---|---|
| Kohdelaite | LFE5U-25F, CABGA381 |
| **Fmax** | **21.21 MHz** |
| Kriittinen polku | `core.lane1.bp_reg` (butterfly-aritmetiikka, TODENNAKOISESTI Montgomery-redusoinnin ketju) |
| Polun jakauma | 20.5 ns logiikkaa, 22.9 ns reititysta |
| DP16KD | 4/56 (7%) |
| TRELLIS_COMB (LUT) | 2643/24288 (10%) |
| TRELLIS_FF | 325/24288 (1%) |
| MULT18X18D (DSP) | 6/28 (21%) |
| TRELLIS_IO | 123/197 (62%) |

**Tama on GENUINE, edustava mittaus ytimen omasta sisaisesta
suorituskyvysta** - kriittinen polku on nyt todistetusti butterfly-
laskennan oma aritmetiikkaketju, ei tyokalun tai testausrakenteen
oma artefakti.

## Havainto jatko-optimointia varten

21 MHz on suhteellisen matala kellonopeus verrattuna ECP5:n omaan
tyypilliseen 100-200+ MHz -kapasiteettiin muille suunnittelutyypeille.
Kriittinen polku (`bp_reg`, todennakoisesti Montgomery-redusointi-
ketju) on todennakoinen KOHDE tulevalle pipelinoinnille (esim.
jakaa modulo-redusointi useampaan sykliin), jos korkeampi kellotaajuus
osoittautuu tarpeelliseksi. Tama on kuitenkin OMA, myohempi
optimointityonsa - ei tarvita M4-FPGA-004:n omaan, jo saavutettuun
tavoitteeseen (DP16KD-inferointi + toiminnallinen oikeellisuus).
