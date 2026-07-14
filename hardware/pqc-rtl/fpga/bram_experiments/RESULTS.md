# M4-FPGA-002, koe 1: mika muistirakenne inferoituu ECP5 DP16KD:ksi Yosysilla

**Tavoite (kayttajan oma kysymys #1):** selvittaa millainen
muistirakenne inferoituu ECP5:n DP16KD-lohkoihin Yosysilla, ennen
kuin kosketaan oikeaan kryptografiseen RTL:aan.

Kaikki kokeet: `yosys synth_ecp5`, sama tyokaluketju kuin
M4-FPGA-001:ssa.

| # | Kuvio | Tulos | Solumaara |
|---|---|---|---|
| 1 | Yksi muisti, 1w+1r, suora osoite | ✅ 1x DP16KD | 81 |
| 2 | Nelja pankkia + ulkoinen ROM-pohjainen valinta (= pqc_ntt_stage_banked:n oma kuvio) | ❌ TRELLIS_DPR16X4 (hajautettu) | 660 |
| 3 | Yksi muisti, 1w+2r (kaksi lukuporttia) | ✅ 2x DP16KD | 125 |
| 4 | Yksi muisti, 2w+2r (nelja porttia) | ❌ Hajautettu logiikka | 35810 |
| 5 | KAKSI erillista yksinkertaista muistia, kumpikin 1w+1r | ✅ 2x DP16KD | 144 |

## Johtopaatokset

1. **Case-pohjainen pankinvalinta (bank_rom-lookup) rikkoo BRAM-
   inferoinnin taysin** (koe 2 vs. koe 1/3/5) - Yosysin memory_bram-
   vaihe ei tunnista talla tavalla "hajautettua" muistikuviota, vaikka
   lopputulos olisi loogisesti identtinen suoraan indeksoituun
   muistiin nahden.

2. **ECP5:n DP16KD tukee KORKEINTAAN 2 porttia per instanssi**
   (koe 3 toimii, koe 4 EI) - jos tarvitaan enemman kuin 2 porttia
   (esim. 2 kirjoitusta + 2 lukua samalle muistialueelle samassa
   syklissa), tarvitaan JOKO useampi muisti-instanssi TAI portti-
   maaran vahentaminen (esim. ajoituksen jakaminen useampaan sykliin).

3. **PARAS TAYTEEN TAVOITTEESEEN sopiva ratkaisu (koe 5):** korvata
   nelja-pankkinen + ROM-valintainen rakenne KAHDELLA (tai useammalla)
   ERILLISELLA, suoraan osoitetulla muistilla - yksi per lane, EI
   yhteista pankinvalintalogiikkaa. Tama vastaisi tarkasti
   pqc_ntt_stage_banked:n oikeaa kayttotarvetta (lane0 ja lane1
   lukevat+kirjoittavat rinnakkain), MUTTA vaatisi etta datan
   looginen->fyysinen osoitekartoitus (nykyinen bank_rom/local_rom)
   korvattaisiin suoralla, MUISTIKOHTAISELLA osoitteella - tama ON
   arkkitehtuurimuutos (kayttajan oma huomio: "vasta tama jalkeen
   harkita arkkitehtuurimuutoksia, jos niita todella tarvitaan").

## Ei viela tehty

Ei kosketa pqc_ntt_stage_banked.sv:aan tassa kokeessa - taydellisesti
eristetyt, minimaaliset kokeilumallit fpga/bram_experiments/-
hakemistossa. Mahdollinen arkkitehtuurimuutos (koe 5:n kuvion
soveltaminen oikeaan ytimeen) on oma, erillinen paatoksensa - vaatisi
huolellisen, vaiheistetun suunnittelun (uusi osoitekartoitus,
regressio golden-malliin, jne.) ennen toteutusta.
