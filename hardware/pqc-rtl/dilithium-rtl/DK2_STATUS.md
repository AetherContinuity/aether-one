# M5-DILITHIUM-001 DK2: ExpandA (A-matriisin nayttestys)

**Paivamaara:** 2026-07-19
**Tila:** Polynomikohtainen naytteenotto (RejNTTPoly) VALMIS ja
todennettu.

## Toteutus

`pqc_dilithium_rej_ntt_poly.sv` - FIPS 204 Algoritmi 30:n mukainen
yhden (i,j)-polynomin nayttestys, kayttaen suoraan jo todistettua
`pqc_shake128.sv`-ydinta (sama SHAKE128 kuin ML-KEM:n omassa
SampleNTT:ssa).

**Tarkistettu HUOLELLISESTI suoraan kirjaston lahdekoodista** (ei
oletettu): `seed = rho || bytes([j, i])` - HUOM JARJESTYS: j ENSIN,
sitten i. Tama on tasan se tyyppinen indeksointi-yksityiskohta joka
aiheutti aiemman sekaannuksen ML-KEM-Decapsin A-matriisin
transpoosityossa - tallä kertaa tarkistettu etukateen kirjaston
omasta koodista, ei kasin paateltyna.

**Nayttestys:** 3 tavua/naytemaara -> 1 kerroin (23-bittinen,
pikkuendian, MSB nollattu 0x7FFFFF-maskilla), hylataan jos >= Q.
Hyvaksymisosuus ~99.9% (Q/2^23) - 280 naytetta (840 tavua XOF-
ulostuloa) riittaa KAYTANNOSSA AINA. `error_exhausted`-signaali
dokumentoi taman rajauksen (jos EI riittaisi - aarimmaisen
epatodennakoinen - moduuli EI taman ensimmaisen version puitteissa
pyyda lisaa XOF-tavuja).

## Testitulos

Nelja eri (i,j)-yhdistelmaa (3,5 / 0,0 / 5,0 / 1,4), KAIKKI PASS
ensimmaisella yrityksella, `error_exhausted=0` kaikissa:

```
Valmis 409 syklin jalkeen (error_exhausted=0)
PASS: RejNTTPoly tasmaa taydellisesti kaikille 256 kertoimelle
```

**EI YHTAAN LOYDETTYA BUGIA.** Kolmas peräkkäinen "PASS ensimmaisella
yrityksella" -kokemus Dilithium-tyossa (butterfly, koko NTT
forward+inverse, nyt ExpandA) - huolellinen etukateistarkistus
kirjaston omasta lahdekoodista (erityisesti j/i-jarjestys) nayttaa
kannattavan johdonmukaisesti.

## Seuraava askel

Koko A-matriisin (K*L=30 polynomia) silmukointi taman moduulin ylla -
kutsu `rejection_sample_ntt_poly`-vastaavaa 30 kertaa eri (i,j)-
pareilla, tallenna tulokset. Suoraviivainen laajennus, sama periaate
kuin ML-KEM:n omassa A-matriisin silmukoinnissa (KeyGenissa/
Decapsissa).

## KOKO A-MATRIISI VALMIS - PASS ENSIMMAISELLA YRITYKSELLA (2026-07-19, jatko)

**Toteutus:** `pqc_dilithium_expand_a.sv` - silmukoi jo todistetun
`pqc_dilithium_rej_ntt_poly.sv`:n 30 kertaa (K=6 x L=5), tallentaen
tulokset sisaiseen (ei-porttina-olevaan, siis Icarus-turvalliseen)
unpacked-taulukkoon, litistettyna lopuksi paketoiduksi ulostuloksi.

**Testitulos:**
```
Valmis 12399 syklin jalkeen
PASS: koko A-matriisi (30 polynomia) tasmaa taydellisesti
```

**PASS TAYDELLISESTI ENSIMMAISELLA YRITYKSELLA kaikille 30
polynomille** - verrattu suoraan `dilithium-py`:n omaan
`_generate_matrix_from_seed()`-metodiin. EI YHTAAN LOYDETTYA BUGIA -
neljas perakkainen "PASS ensimmaisella yrityksella" -kokemus
Dilithium-tyossa.

**Mitattu suorituskyky:** 12399 sykli / 30-polynomin A-matriisi ≈
413 sykli/polynomi keskimaarin, matchaa aiemmin mitatun yksittaisen
polynomin (409 sykli) kanssa.

## DK2:n LOPULLINEN tila

| Osa | Tila |
|---|---|
| RejNTTPoly (yksi polynomi) | ✅ |
| Koko A-matriisi (30 polynomia) | ✅ |
| Synteesi + tarkka Fmax-mittaus | ❌ Avoin (sama rajaus kuin DK1:ssa) |

**DK2 on nyt funktionaalisesti ja metodologisesti valmis** - sama
nelja hyvaksymiskriteeria kuin DK1:lla (algoritminen oikeellisuus ✅,
regressiotestit ✅, synteesikelpoisuus/suorituskyky osittain samasta
P&R-aikarajoituksesta johtuen kuin DK1:ssa).

## Seuraava askel

ExpandS: `s1` (L=5 polynomia) ja `s2` (K=6 polynomia) nayttestys
SamplePolyCBD:n SIJAAN kaytetaan RejBoundedPoly-menetelmaa (ETA=4) -
ERI nayttestysmenetelma kuin ML-KEM:n oma CBD, tarvitsee oman RTL-
toteutuksensa.
