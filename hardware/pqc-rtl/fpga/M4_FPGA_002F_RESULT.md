# M4-FPGA-002F: feature-elimination-sarjan tulos - EI yhtaan yksittaista syyllista

**Tavoite:** eristaa, mika YKSITTAINEN piirre (arbitrointi, konfliktin-
tunnistus, bring-up-portit, ROM-haku, kaksoisohjain) estaa BRAM-
inferoinnin oikean arkkitehtuurin sisalla, poistamalla yksi kerrallaan
128-pankkisesta tutkimusprototyypista (`pqc_ntt_stage_banked_prototype_128banks.sv`).

## Tulokset

| Koe | Muutos | DP16KD? | Solumaara |
|---|---|---|---|
| (lahtotilanne) | ei muutosta | ❌ | 96878 |
| 002F-5 | lane1 poistettu kokonaan | ❌ | 53790 |
| 002F-3b | bring-up-kirjoitus poistettu, luku sailytetty | ❌ | 86467 |
| 002F-2 | req/grant ohitettu (grant=1 aina) | ❌ | 92778 |
| 002F-1 | konfliktintunnistus poistettu | ❌ | 96289 |
| 002F-4 | ROM-haku korvattu XOR-kaavalla | ❌ | 126344 |

**YKSIKAAN yksittainen piirteen poisto EI riittanyt yksinaan
BRAM-inferoinnin mahdollistamiseksi.**

## Johtopaatos

Este ei ole mikaan YKSITTAINEN, eristettavissa oleva piirre. Tama
viittaa kahteen mahdolliseen selitykseen:

1. **Useamman tekijan yhteisvaikutus** - esimerkiksi kaksi NAISTA
   yhdessa (esim. lane1 JA bring-up yhdessa) saattaisi riittaa, vaikka
   kumpikaan yksinaan ei riita. Tama vaatisi yhdistelmakokeita
   (2^5=32 mahdollista yhdistelmaa, tai kohdennetumpi valikoima).
2. **Yosysin `memory_bram`-passin oma monimutkaisuus-/kokoraja** koko
   yhdistetylle netlistille - riippumatta SIITA, mika yksittainen osa
   sen aiheuttaa, itse NETLISTIN kokonaislaajuus (84-110 tuhatta
   solmua ENNEN tekniikka-kartoitusta) saattaa ylittaa jonkin
   sisaisen kynnyksen jonka jalkeen memory_bram ei enaa yrita
   BRAM-kartoitusta lainkaan tietylle muistiobjektille.

Kayttajan oma huomio (todennakoisin selitys tassa vaiheessa):
"Todennakoisesti kyse on kokonaisesta muistiverkosta, jonka Yosysin
memory_collect- ja memory_bram-vaiheet eivat enaa tunnista
inferoitavaksi" - tama LOYDOS TUKEE tata hypoteesia, koska mikaan
YKSITTAINEN piirteen poisto ei riittanyt.

## Ei viela ratkaisua

Kaikki kokeet pysyvat `fpga/`-hakemistossa tutkimusprototyyppeina.
Tuotantoydin (`rtl/pqc_ntt_stage_banked.sv`) on TAYSIN koskematon,
M3:n regressiot ja CI pysyvat vihreina.

## Seuraava mahdollinen suunta

Kun mikaan yksittainen ominaisuuksien poisto ei riittanyt, seuraava
looginen askel olisi joko:
(a) yhdistelmakokeet (esim. lane1+bring-up yhdessa poistettuna), TAI
(b) siirtyminen kokonaan toiseen arkkitehtuuriin (koe 12:n yhtenainen
    muisti + osoitepermutaatio, joka JO toimi ERISTETYSSA kokeessa) -
    tama vaatisi kuitenkin ajoitusmuutoksen (DP16KD:n 2-porttirajoitus)
    hyvaksymista, koska nykyinen 2-lane-rinnakkaisuus ei mahdu 2
    porttiin.
