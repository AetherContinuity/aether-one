# M4-FPGA-002E: tulos - 64->128 EI RIITA oikeassa arkkitehtuurissa

**Kysymys:** "Onko 64->128 yksin riittava?" (kayttajan oma, tarkasti
rajattu hypoteesi ennen tuotantomuutosta)

**Vastaus: EI.**

## Menetelma

Eristetty tutkimusprototyyppi (`pqc_ntt_stage_banked_prototype_128banks.sv`,
TAYSI KOPIO `rtl/pqc_ntt_stage_banked.sv`:sta - EI kosketa tuotantoydinta),
jossa AINOA muutos on pankkien koko 64->128 (bank_rom/local_rom,
osoitelogiikka, FSM, konfliktintunnistus, bring-up-portit - KAIKKI
muu TASMALLEEN samaa kuin tuotantoytimessa).

Todennettu ensin TOIMINNALLISESTI OIKEAKSI (simulaatio, koko 7-tasoinen
NTT, NTT_READ_LATENCY=1): PASS, tasmaa golden-malliin, ei konflikteja.

Synteesoitu (`FPGA_BRINGUP=1`, `NTT_READ_LATENCY=1`, sama kuin edellinen
tuotantoytimen testi): **96878 solua, EI DP16KD:ta** - kaytannossa
identtinen tulos kuin 64-alkioisilla pankeilla (96622 solua).

## Johtopaatos

Eristetty koe 11 (M4-FPGA-002A: nelja erillista 128-alkioista
muistia, YKSINKERTAISILLA, OMISTETUILLA porteilla, EI muuta logiikkaa)
inferoitui onnistuneesti (4x DP16KD, 288 solua).

TAMA prototyyppi (sama 128-koko, MUTTA upotettuna TAYTEEN oikeaan
rakenteeseen - lane_fsm, req/grant-arbitrointi, bank_rom/local_rom-
haku, konfliktintunnistus, bring-up-portit) EI inferoitunut.

**Tama todistaa: 64->128-koonmuutos YKSINAAN EI riita oikeassa
arkkitehtuurissa - on olemassa KOLMAS tekija jota pienet eristetyt
kokeet eivat ole mallintaneet.** Todennakoisia ehdokkaita jatko-
tutkimukselle: req/grant-arbitrointilogiikka, konfliktintunnistus-
logiikan (`bank_conflict_detected`) yhteys osoitteisiin, tai
bring-up-porttien oma yhteisvaikutus muun logiikan kanssa.

## Vaikutus jatkotyohon

**EI VIELA pysyvaa arkkitehtuurimuutosta tuotantoytimeen** - kayttajan
oma, oikea johtopaatos ennen tata koetta oli tama tasmalleen: odota
tuloksia ennen sitoutumista. Nyt tiedetaan etta pelkka koonmuutos ei
riita - seuraava tutkimusaskel on eristaa TARKALLEEN mika lisatekija
(arbitrointi, konfliktintunnistus, bring-up-portit) estaa inferoinnin,
todennakoisesti rakentamalla VALIVAIHEEN prototyyppeja (esim. 128-koko
+ pelkka arbitrointi, ilman konfliktintunnistusta; 128-koko + pelkka
konfliktintunnistus, ilman bring-up-portteja; jne.) ennen kuin
lopullinen, taydellinen yhdistelma testataan.
