# M2 Vaihe 2a — Kyber-NTT Python-golden-malli

Ei RTL:ää. Puhdas Python-referenssi Kyberin/ML-KEM:n oikealle NTT:lle
(FIPS 203, Algoritmit 9 ja 10) + BaseCaseMultiply-pistetulolle, ennen
kuin mitään RTL:ää kirjoitetaan (ks. `../M2_DESIGN_NOTE.md`).

## Mitä tämä TODISTAA

- **NTT⁻¹(NTT(f)) = f** — round-trip-identiteetti, 5/5 satunnaista
  256-kertoimista polynomia, kahdella eri satunnaissiemenellä (2026, 31337).
- **Konvoluutiolause, RIIPPUMATTOMASTI todennettu:**
  `INTT(NTT(a) ⊙ NTT(b)) = a·b mod (X²⁵⁶+1)`, missä `⊙` = BaseCaseMultiply
  per 128 paria. Oikea puoli laskettu **suoralla koulukirja-negasyklisellä
  konvoluutiolla, joka ei käytä NTT:tä lainkaan** — eri algoritmi, eri
  koodipolku. Jos NTT/INTT/BaseCaseMultiply sisältäisivät saman
  systemaattisen virheen molemmissa suunnissa, pelkkä round-trip-testi
  voisi silti läpäistä virheellisenä; koulukirjavertailu ei voi tehdä
  tätä virhettä koska se ei jaa mitään koodia NTT-toteutuksen kanssa.
- **Negatiivikontrolli**: tahallaan rikottu `BaseCaseMultiply` (väärä
  etumerkki gammalle, samantyyppinen virhe kuin Dilithium/Kyber-
  gamma-konvention sekoittaminen) tuottaa todistetusti väärän tuloksen
  (128/256 sanaa eroaa oikeasta) — negatiivikontrolli toimii, ei vain
  näyttele läpäisyä.

## Mitä tämä EI todista

- Ei RTL:ää, ei synteesikelpoisuutta, ei ajoitusta.
- Ei ole verrattu ulkopuoliseen referenssitoteutukseen (esim.
  pq-crystals/kyber-referenssikoodiin) — vain sisäinen konvoluutiolause-
  ristiintarkistus. Tämä on riippumaton todennus algoritmin sisäisestä
  oikeellisuudesta, mutta ei vahvista että `ZETA=17` tai `BitRev7`-
  toteutus täsmää tavu tavulta pq-crystals-referenssiin (todennäköisesti
  täsmää, koska molemmat nojaavat samaan FIPS 203 -tekstiin, mutta
  ei erikseen tässä vahvistettu ulkoista koodia vasten).
- Ei sisällä `SampleNTT`-, `SamplePolyCBD`- tai muita ML-KEM:n
  ympäröiviä funktioita — vain NTT/NTT⁻¹/BaseCaseMultiply itsessään.

## Aja itse

```
python3 kyber_ntt_golden.py
```

## Seuraava askel (M2 Vaihe 2b)

Laajennus M2 Vaihe 1:n toimivasta yhden-tason-16-butterflyn RTL-
rakenteesta: yksi taso (level 6, 128 butterflya, ensimmäinen taso)
tästä 7-tasoisesta mallista, testattuna tätä golden-mallia vasten.
