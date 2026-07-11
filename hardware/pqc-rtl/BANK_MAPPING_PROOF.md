# M2 Vaihe 3a — Muodollinen todistus: 4-pankkinen konfliktiton kuvaus

## Väite

> "On olemassa tasoriippumaton kuvausfunktio bank: {0..255} -> {0,1,2,3},
> joka täyttää konfliktittomuusehdot kaikilla seitsemällä NTT-tasolla
> annetulla 2-lane-aikataululla."

## Menetelmä

SAT-koodaus Z3:lla (versio 2, `bank_mapping_sat_proof_v2.py`):
- 256 kokonaislukumuuttujaa `bank_0..bank_255`, kukin välillä [0,4)
- Jokaiselle todellisesti SAMANAIKAISELLE osoitenelikölle (a0,b0,a1,b1)
  rajoite `Distinct(bank[a0], bank[b0], bank[a1], bank[b1])`

**Riippumattomuus:** nelikkolista luetaan SUORAAN
`vectors/full_schedule.txt` + `vectors/full_level6_zeta.txt` -
tiedostoista, jotka ovat NE TARKAT tiedostot jotka jo ajoivat ja
läpäisivät oikean, todennetun M2 Vaihe 2c-ii RTL-simulaation
(`tb/pqc_ntt_full_tb.sv`). Ei erillistä, käsin uudelleenkirjoitettua
Python-abstraktiota aikataulusta.

**Ensimmäinen versio (v1, `bank_mapping_sat_proof.py`) oli virheellinen
tavalla joka löytyi vasta v2:ta rakentaessa:** v1 käsitteli tason 6
(1 ryhmä) sarjallisena yhden lanen prosessina, vaatien vain 2-suuntaisen
erillisyyden 128 kertaa. Todellisuudessa `pqc_ntt_level6_2lane` ajaa
molemmat lanet SAMANAIKAISESTI saman ryhmän eri puoliskoilla (lane0:
j=0..63 osoitteesta 0, lane1: j=0..63 osoitteesta 64, molemmat
pair_dist=128) - oikea vaatimus on 4-suuntainen erillisyys 64 kertaa,
ei 2-suuntainen 128 kertaa. v2 korjaa tämän. **v2:n vahvempi, oikea
rajoitejoukko silti palautti SAT** - tulos on siis todennettu oikealla
vaatimuksella, ei aliarvioidulla.

## Tulos

**SAT** (ei UNSAT). Väite on TOSI: kiinteä, tasoriippumaton 4-pankkinen
kuvaus ON olemassa.

- 448 nelikkoa (64 tasolta 6 + 384 tasoilta 5..0), 512 muuttujarajoitetta
- Riippumaton brute force -uudelleenvarmennus SAMALLA nelikkolistalla: 0 virhettä
- Pankkien jakauma: **64/64/64/64** (täydellisesti tasapainossa)
- v1 ja v2 antavat saman SAT-tuloksen huolimatta v1:n omasta,
  löydetystä puutteesta - v2 on silti autoritatiivinen, koska sen
  rajoitejoukko on oikea

## Mitä tämä EI todista

- Ei suljettua bittikaavaa - ratkaisu on tällä hetkellä raaka 256-alkioinen
  taulukko (ROM, 512 bittiä). Optimointi (elegantimpi kaava) on erillinen,
  myöhempi vaihe - ei toiminnallisen oikeellisuuden edellytys.
- Nelikkolista on Python-generoitu (`gen_full_ntt_vectors.py`, joka
  käyttää `ntt()`-funktion silmukkarakennetta) - ei kielirajat ylittävää
  riippumattomuutta (esim. C-referenssiä vasten), vaan sidottu siihen
  tarkkaan aikatauluun jota oikea, simuloitu RTL tosiasiassa suoritti.

## Seuraava askel (M2 Vaihe 3b)

Toteuta ROM-taulukko (256x2 bittiä) RTL:ssä käyttäen tätä Z3:n löytämää
kuvausta, yhdelle NTT-tasolle aluksi. Optimointi (suljettu kaava) vasta
kun koko M2 toimii ROM-pohjaisena.
