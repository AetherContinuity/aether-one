# M5-DILITHIUM-001 DK3: ExpandS (s1/s2:n nayttestys)

**Paivamaara:** 2026-07-19
**Tila:** Polynomikohtainen naytteenotto (RejBoundedPoly) VALMIS ja
todennettu.

## Toteutus

`pqc_dilithium_rej_bounded_poly.sv` - FIPS 204 Algoritmi 31:n
mukainen yhden polynomin nayttestys ETA=4:lle (ML-DSA-65:n oma
parametri), kayttaa SHAKE256:ta (ERI kuin ExpandA:n SHAKE128).

**Loydetty ja korjattu ITSE, ENNEN lopullista testausta:** alkuperainen
`rho_prime_in`-portti oli VAARIN mitoitettu 32 tavuksi (256 bittia) -
todellisuudessa `rho_prime` on 64 tavua (SHA3-512:n oma ulostulokoko,
kayttopaikassa KeyGenissa). Korjattu 512-bittiseksi ja SHAKE256:n
oma `msg_len_bytes` paivitetty 66:een (64+2) ennen testausta.

**Naytteenotto:** yksi tavu -> KAKSI nelijasta (alempi ensin, sitten
ylempi), kummallekin: jos nelijas < 9, kerroin = 4-nelijas (arvot
4..−4), muuten HYLATAAN. Hyvaksymisosuus 9/16=56.25% per nelijas.
408-tavuinen XOF-puskuri (3 SHAKE256-lohkoa) - reilu turvamarginaali
(odotettu keskimaarin ~228 tavua).

**Ulostulo on RAAKA ETUMERKILLINEN arvo** (-4..4), EI Zq-muunnettu -
tasmaa SUORAAN `dilithium-py`:n omaan `coeffs`-listaan, pitaen
vertailun yksinkertaisena.

## Testitulos

Nelja eri indeksia (2, 0, 4, 10), KAIKKI PASS ensimmaisella
(korjatulla) yrityksella, `error_exhausted=0` kaikissa:

```
Valmis 534-575 syklin jalkeen (error_exhausted=0)
PASS: RejBoundedPoly tasmaa taydellisesti kaikille 256 kertoimelle
```

Syklimaara vaihtelee (534-575) hylkaysten satunnaisen maaran mukaan -
odotettu kayttays hylkaysnayteenotolle, EI virhe.

**EI YHTAAN LOYDETTYA BUGIA** (rho_prime-leveyskorjaus tehtiin ITSE,
ennen ensimmaista testiajoa, tarkistamalla kayttopaikan oma konteksti
huolellisesti).

## Seuraava askel

Koko `s1` (L=5 polynomia) ja `s2` (K=6 polynomia) -vektoreiden
silmukointi taman moduulin ylla, sama periaate kuin ExpandA:n omassa
30-polynomin silmukoinnissa.
