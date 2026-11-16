# B4: tulos

**Ajettu:** 2026-11-16. Ennakkorekisteröinti `B4-ENNAKKO.md` (commit c2dabe2)
ennen Yosys-ajoa. Yosys 0.33, 2 CPU, 6 GiB:n muistiraja.
Tallennettu tuloste: `b4/tulokset/decaps_a_core_k3.stat`.

## Mittausputken korjaukset (ei koske hypoteeseja)

Ennen ensimmäistä onnistunutta ajoa:
1. `read_verilog -sv` ilman `-defer` ja `hierarchy -chparam K 3` kaatui
   Yosysin sisäiseen tarkistukseen (`Assert modules_.count(module->name) == 0`).
   K=3 on ytimien oletus, joten parametri jätettiin asettamatta ja luku
   tehtiin `-defer`-valitsimella.
2. `write_json -selected` ei ole Yosys 0.33:ssa. FF-bitit luetaan
   `stat -width`-tulosteesta (`b4/ff_bitit.py`).

Ennakkoon kirjattu vaihejono (`proc; opt; memory -nomap; opt_clean`, ei
flattenia) ja hylkäyssäännöt ovat ennallaan.

## Tulos

| | Arvio | Yosys | Suhde |
|---|---|---|---|
| `pqc_mlkem_decaps_a_core`, oma taso, K=3 | 84 952 | **82 330** FF-bittiä | 96,9 % |
| sama + alimoduulit | – | 89 470 | – |

Ajo kesti 837 s (pelkkä `proc`/`opt`, ei teknologiakartoitusta).
Yosys jätti kaksi `$mem_v2`-solua, joiden leveys ei näy statissa; niitä ei
ole laskettu mukaan. Jos ne muuttuvat rekistereiksi, luku vain kasvaa.

**H1 pätee:** 96,9 % on välillä 50–110 %. Arvio osui lähes tarkasti.
Yosys ei poistanut 16-bittisten kerroinrekisterien ylimpiä nollabittejä tässä
vaiheessa (`$dffe_4096` × 11).

**H2 pätee 25F:lle:** pienin ydin yksinään vie 82 330 FF-bittiä, ja
LFE5U-25F:ssä on 24 288 FF:ää (3,4-kertainen ylitys). **85F:lle H2 nojaa
arvioon:** koko kääre ≈ 685 000 bittiä alimoduuleitta, eli noin 8 kertaa
LFE5U-85F:n 83 640 FF:ää. Koska arvio osui a_coressa 97 %:iin, ylitys ei
ole arviointivirheen selitettävissä.

**H3 (laskettu, ei mitattu):** 94 polynomia × 256 × 16 bittiä mahtuu noin
24 DP16KD-lohkoon; 25F:ssä niitä on 56.

## Mitä tästä seuraa

B4:n "synteesi ei valmistunut" ei ole työkalu- tai resurssiongelma, jota
korjattaisiin isommalla koneella. Arkkitehtuuri pitää jokaisen polynomin
rinnakkaisrekisterissä, jotta polynomin voi koodata ja purkaa yhdellä
kombinatorisella askeleella. Synteesi ei voi mahtua ECP5:lle tällä
rakenteella.

Seuraava askel on arkkitehtuurimuutos, ei mittaus:
- polynomit BRAM:iin (yksi kerroin per sana), ByteEncode/Decode ja
  Compress kerroin kerrallaan virtana;
- A-matriisi generoidaan sarake kerrallaan, kun sitä tarvitaan, eikä
  tallenneta kokonaan;
- yksi jaettu Keccak, NTT ja SampleNTT kaikille kolmelle operaatiolle.

Tämä on iso uudelleenkirjoitus. Nykyinen RTL ja sen todennus (ACVP, B8)
jäävät referenssiksi, jota vasten uutta toteutusta voidaan verrata
syklitasolla ja tulostasolla.

## Rajaukset

- Mitattiin yksi moduuli, pienin. Muut (b1_core, keygen_core) perustuvat
  samaan arviointimenetelmään.
- FF-bitit ennen teknologiakartoitusta; ECP5-kartoitus ei ole ajettu.
- LUT-määrää ei ole arvioitu eikä mitattu.
