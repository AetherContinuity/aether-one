# Montgomery-reduktion korjaus (2026-07-10)

## Havainto

M2 Vaihe 2b:tä toteuttaessa (oikea FIPS 203 -zeta-arvo, level 6 = 1729)
`montgomery_reduce`-funktion tulos ei täsmännyt Python-golden-malliin,
vaikka M1 ja M2 Vaihe 1 olivat molemmat läpäisseet omat testinsä.

## Juurisyy

`lane_fsm`:n `montgomery_reduce` (ja sen Python-vastine `gen_vectors.py`:ssä)
käytti kaavaa:
```
u = (a & 0xFFFF) * QINV & 0xFFFF     (etumerkiton)
t = (a + u * Q) >> 16                 (YHTEENLASKU)
```

Todellinen pq-crystals/kyber-referenssi (`ref/reduce.c`, tarkistettu
suoraan lähdekoodista, ei muistista):
```c
int16_t montgomery_reduce(int32_t a) {
  int16_t t;
  t = (int16_t)a*QINV;
  t = (a - (int32_t)t*KYBER_Q) >> 16;   // VÄHENNYS, signeerattu t
  return t;
}
```

`QINV=62209` oli **aina oikea** arvo tälle referenssikaavalle. Vika oli
operaattorissa (yhteenlasku vähennyksen sijaan) ja etumerkkitulkinnassa
(etumerkitön signeeratun sijaan) - ei vakion arvossa.

## Miksi M1/M2 Vaihe 1 eivät huomanneet tätä

Kumpikin testasi vain **sisäistä johdonmukaisuutta**: sama (virheellinen)
kaava sekä Python-mallissa että RTL:ssä, joten ne täsmäsivät toisiinsa
vaikka kumpikaan ei laskenut todellista Montgomery-reduktiota. Kumpikaan
testi ei koskaan verrannut tulosta ulkoiseen, absoluuttiseen määritelmään
(FIPS 203 / pq-crystals-referenssi).

Tämä havaittiin vasta kun M2 Vaihe 2b yritti täsmätä oikeaan, ulkoisesta
lähteestä (FIPS 203) peräisin olevaan zeta-arvoon 128. yksikönjuuresta -
ero sisäisen johdonmukaisuuden ja normatiivisen (standardin mukaisen)
oikeellisuuden välillä.

## Kolmitasoinen todennus korjauksen jälkeen

1. **Sisäinen konsistenssi** (RTL = oma Python-golden): PASS, M1/M2 Vaihe 1
   ja M2 Vaihe 2b kaikki läpäisevät oman golden-mallinsa.
2. **Normatiivinen konsistenssi** (RTL = pq-crystals/kyber-referenssi):
   erillinen SystemVerilog-yksikkötesti (5 tunnettua arvoa suoraan
   Python-referenssistä laskettuna) PASS. Korjattu `montgomery_reduce`
   tuottaa tasmalleen saman tuloksen kuin `ref/reduce.c`.
3. **Regressio** (M1/M2 Vaihe 1 eivät hajonneet korjauksesta): molemmat
   ajettu uudelleen korjatulla aritmetiikalla ja UUSILLA (korjatulla
   kaavalla generoiduilla) golden-vektoreilla - PASS molemmat, mukaan
   lukien niiden omat negatiivikontrollit.

## Muutetut tiedostot

- `rtl/pqc_rvv_cluster_2lane.sv`: `montgomery_reduce`-funktio korjattu
- `gen_vectors.py`: Python-vastine korjattu samaksi
- `m2-golden/gen_level6_vectors.py`: zeta-esiskaalaus yksinkertaistui
  (ei enää tarvitse negaatiota, koska kaava on nyt oikea - standardi
  `zeta_mont = zeta*R mod Q` riittää)

## Suositus jatkoa varten

Jos projektiin lisätään myöhemmin ML-DSA/Dilithium-puolen Montgomery-
reduktio (eri Q, eri QINV), sama normatiivinen tarkistus kannattaa tehdä
SILLE erikseen pq-crystals/dilithium-referenssiä vasten ennen kuin
oletetaan saman kaavamuodon toimivan sellaisenaan.
