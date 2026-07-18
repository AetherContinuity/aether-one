# M4-TAU: koko ML-KEM-protokolla VALMIS yhdessa TAU-kehyksessa

**Paivamaara:** 2026-07-19
**Tila:** TAYDELLINEN, PAASTA-PAAHAN-VALIDOITU VIRSTANPYLVAS

## Mika tama on

Tama on ensimmainen testi joka validoi KOKO ML-KEM-protokollan
(KeyGen -> Encaps -> Decaps) yhden TAU-kehyksen sisalla, EI vain
yksittaisia algoritmeja erikseen. ECU:n nakokulmasta:

```
ECU
 |
 |-- KeyGen (satunnainen d_seed+z_seed) -> ek, dk
 |
 |-- Encaps (KeyGenin OMA ek + satunnainen viesti) -> K_encaps, c
 |
 |-- Decaps (KeyGenin OMA dk + Encapsin OMA c) -> K_decaps
 |
 |-- TARKISTUS: K_encaps === K_decaps
```

## Symmetria saavutettu ensin

Ennen taman testin rakentamista viimeisteltiin Encapsin oma audit-
loki- ja watchdog-integraatio (ENCAPS_STARTED, ENCAPS_COMPLETED,
ENCAPS_WATCHDOG_INTERRUPTED - samat kolme tapahtumatyyppia kuin
KeyGenilla ja Decapsilla). Tama saavutti taydellisen symmetrian:

| Toiminto | Audit | Watchdog |
|---|---|---|
| KeyGen | ✅ | ✅ |
| Decaps | ✅ | ✅ |
| Encaps | ✅ | ✅ |

## Testitulos

```
=== Vaihe 1: KeyGen ===
OK: KeyGen valmis 3780 syklin jalkeen
ek + dk luettu takaisin Wishbone-vaylan kautta
=== Vaihe 2: Encaps ===
OK: Encaps valmis 4800 syklin jalkeen
K_encaps + c luettu takaisin Wishbone-vaylan kautta
=== Vaihe 3: Decaps ===
OK: Decaps valmis 7283 syklin jalkeen
OK: Decapsin oma match=1 (aito ciphertext)
K_decaps luettu takaisin Wishbone-vaylan kautta
=== Lopullinen tarkistus ===
PASS: K_encaps === K_decaps - KOKO ML-KEM-PROTOKOLLAKETJU TOIMII PAASTA PAAHAN!
PASS: KOKO ML-KEM-PROTOKOLLA (KeyGen->Encaps->Decaps) TOIMII YHDESSA TAU-KEHYKSESSA
```

**KRIITTINEN VALIDOINTIYKSITYISKOHTA:** kaikki syotteet (d_seed,
z_seed, viesti) ovat TAYSIN SATUNNAISIA (`$random`-generoituja tassa
testissa) - EI mitaan aiemmin jaadytettya, kasin valittua testi-
vektoria. `ek`, `dk`, `c` VALITTUVAT KeyGenin ja Encapsin omien,
juuri-nyt-lasketttujen tulosten VALILLA (luettu Wishbone-vaylan
kautta yhdesta vaiheesta, syotetty SEURAAVAAN vaiheeseen) - tama on
lahin mahdollinen simulaatio siita miten TODELLINEN ECU kayttaisi
TAU:ta oikeassa kayttotilanteessa.

## Mika tama merkitsee koko projektille

Tama sulkee ML-KEM-osuuden (KeyGen+Encaps+Decaps) SEKA algoritmisesti
etta rajapinnallisesti YHTENAISENA kokonaisuutena:

- Kaikki kolme algoritmia TOIMIVAT itsenaisesti (todistettu aiemmin)
- Kaikki kolme kayttavat SAMAA Wishbone-ohjelmointimallia
  (WORD_SEL -> START -> STATUS -> READ BACK)
- Kaikki kolme ovat symmetrisesti audit- ja watchdog-suojattuja
- **Niiden VALINEN yhteistoiminta on nyt TODISTETTU, ei vain oletettu**

## Seuraavat askeleet (kayttajan oma nakemys)

Projektin painopiste siirtyy nyt algoritmien toteuttamisesta:
1. Synteesin loppuunvienti
2. Suorituskyky
3. Resurssien optimointi (Keccak-instanssien jakaminen, jo aiemmin
   tunnistettu mahdollisuus)
4. Dilithiumin lisays samaan palvelukehykseen (GitHub Issue #17)
