# KECCAK_MULTIBLOCK_001.md — debug-paivakirja

**Avattu:** 2026-07-19
**Suljettu:** 2026-07-19 (sama istunto, kayttajan oman ohjatun
jatkotutkimuksen ansiosta)
**Lopputulos:** EI BUGIA Keccak-infrastruktuurissa. Aito bugi loytyi
`pqc_dilithium_pack_dk.sv`:sta - vaara hajautusfunktion valinta
(SHA3-512 SHAKE256:n sijaan).

## Oire (alkuperainen havainto)

DK4:n dk-pakkaus (`tr=H(ek)`, SHA3-512 1952-tavuiselle ek:lle,
28 lohkoa RATE_BYTES=72:lla) epaonnistui: 64/4032 tavua eroaa
(tasmalleen tr:n oma koko).

## Ensimmainen (VAARA) hypoteesi

Kavennettu naennaisesti "3+ lohkoa epaonnistuu, 1-2 lohkoa toimii" -
manuaalisella `$display %h` + Python `bytes.fromhex()`-kopiointi-
menetelmalla. Tulos NAYTTI systemaattiselta tavujarjestyksen
kaantymiselta (`rtl_bytes[::-1] == golden_bytes`, todennettu 3, 4, 5,
28 lohkolle).

**TAMA HYPOTEESI OSOITTAUTUI VAARAKSI** - selviaa alla.

## Kayttajan oma ohjaus jatkotutkimukselle

Kayttaja ehdotti tarkkaa, jarjestelmallista tutkimusjarjestysta:
1. absorb -> f1600 -> absorb -siirtyma useamman lohkon yli
2. lohko-osoittimen (block index) paivittyminen
3. state[1600]-valimuistin kirjoitusjarjestys
4. endian-muunnos lohkorajalla
5. squeeze-vaiheen ensimmaisen lohkon lahtoosoite

Kayttaja huomautti myos tarkeasti: "tavujarjestykseltaan kaannetty"
kuulostaa OSOITUS-/SERIALISOINTIVIRHEELTA, EI kryptografiselta
virheelta (silla jos permutaatio itse olisi vaarin, tulos nayttaisi
SATUNNAISELTA, ei systemaattisesti kaannetylta).

## Systemaattinen tutkimus (taman istunnon jatko-osa)

### Vaihe 1: lane-tason vertailu golden-mallia vasten

Kaytettiin `m2-golden/keccak_golden.py`:n omaa `absorb_instrumented()`-
funktiota (tallentaa tilan JOKAISEN lohkon jalkeen) 196-tavuiselle
(3-lohkoiselle) testiviestille.

**Tulos: KAIKKI KAHdeksAN LANEA (512 ensimmaista bittia) TASMASIVAT
TAYDELLISESTI RTL:n oman `acc_state`:n kanssa jokaisen lohkon
jalkeen** - myos KOLMANNEN (viimeisen) lohkon jalkeen. Absorbointi
ITSESSAAN on siis 100% oikein.

### Vaihe 2: koko acc_state[511:0] vs digest_out

Todettiin etta `digest_out === acc_state[511:0]` TAYDELLISESTI (squeeze
kopioi suoraan, ei omaa uudelleenjarjestelya) - squeeze on siis
VAPAUTETTU epailyksista.

### Vaihe 3: KRIITTINEN VIRHE OMASSA DEBUG-METODOLOGIASSA

Rakennettiin UUSI, TIEDOSTOPOHJAINEN testi (sama periaate kuin
alkuperainen epaonnistunut pack_dk-testi: Python kirjoittaa hex-
tiedoston `int.from_bytes(...,'little')`-muodossa, RTL lukee
`$fscanf("%h",...)`:lla, vertailu `===`:lla) SAMALLE 196-tavuiselle
3-lohkon viestille.

**TULOS: PASS.** Taman jalkeen kavennettiin UUDELLEEN tiedosto-
pohjaisella (LUOTETTAVALLA) menetelmalla: 8, 15, 20, 24, 25, 26, 27,
28 lohkoa - KAIKKI PASSASIVAT synteettisella testidatalla.

**JOHTOPAATOS: alkuperainen "3+ lohkoa epaonnistuu" -havainto OLI OMA
DEBUG-METODOLOGIAVIRHE.** Manuaalinen `$display %h`:n kopiointi
Pythoniin JATTI HUOMIOTTA etta Verilogin `%h` tulostaa MSB-jarjestyk-
sessa, kun taas testipenkin oma `$fscanf+===`-vertailu kayttaa
JOHDONMUKAISESTI "bitti0=tavu0"-konventiota molemmin puolin. Nama
KAKSI eri vertailutapaa EIVAT ole yhteensopivia keskenaan ilman
eksplisiittista tavujarjestyksen kaantoa - taman huomiotta jattaminen
loi NAENNAISEN "bugin" joka EI ollut olemassa.

**Kayttajan oma teoreettinen huomio ("nayttaa osoitusvirheelta, ei
kryptografiselta virheelta") oli TAYSIN OIKEA SUUNTA - mutta itse
kohde oli oma testausmenetelmani, ei RTL.**

### Vaihe 4: aito bugi loytyy - VAARA hajautusfunktio

Koska 28-lohkon SHA3-512 osoittautui TAYSIN OIKEAKSI synteettisella
datalla, mutta epaonnistui edelleen TIEDOSTOPOHJAISESTIKIN TODELLISELLA
`pk`-arvolla (1952 tavua) - kavennettiin viela pidemmalle: verrattiin
`dilithium-py`:n omaa `_h()`-funktiota SUORAAN Pythonin `hashlib.sha3_512`:
een.

**TULOS: ERI ARVOT.** Tarkistettu suoraan `dilithium-py`:n lahdekoodista:

```python
def _h(in_bytes: bytes, length: int) -> bytes:
    return shake256(in_bytes).read(length)
```

**FIPS 204:n oma H()-funktio ON SHAKE256, EI SHA3-512!** Tama on
kaksi ERI algoritmia (eri domain-suffiksi: SHA3=0x06, SHAKE=0x1F) -
oma `pqc_dilithium_pack_dk.sv` kaytti VAARAA moduulia
(`pqc_sha3_512` oikean `pqc_shake256`:n sijaan).

## Korjaus

Vaihdettu `pqc_sha3_512` -> `pqc_shake256` (rate 72->136 tavua,
lohkomaara 28->15) `pqc_dilithium_pack_dk.sv`:ssa.

**TULOS KORJAUKSEN JALKEEN: PASS TAYDELLISESTI**, 433 sykli (NOPEAMPI
kuin alkuperainen VAARA 28-lohkon SHA3-512 olisi ollut, koska
SHAKE256:n oma 136-tavuinen rate tarvitsee VAIN 15 lohkoa).

## Lopullinen johtopaatos

**Keccak-infrastruktuuri (pad, absorb, f1600, squeeze) ON TAYSIN
VIRHEETON** - todennettu POIKKEUKSELLISEN KATTAVASTI (1-28 lohkoa,
seka synteettisella etta todellisella datalla, useilla eri
menetelmilla). Taman istunnon oma, alkuperainen "loydos" ("3+ lohkoa
epaonnistuu jaettu infrastruktuurissa") **OLI VAARA** - todellinen
bugi oli OMASSA, uudessa dk-pakkausmoduulissa (vaara hajautus-
funktion valinta), EI missaan jaetussa, jo aiemmin kaytetyssa osassa.

## Poissuljetut hypoteesit (jarjestyksessa)

1. ~~f1600:n oma round_idx ei nollaudu oikein~~ - EI, nollautuu
   oikein joka start-pulssilla (todennettu koodilukemalla).
2. ~~squeeze lukee vaarasta osoitteesta~~ - EI, squeeze kopioi
   suoraan acc_state:n, ei omaa uudelleenjarjestelya (todennettu
   `===`-vertailulla digest_out ja acc_state valilla).
3. ~~absorb-silmukan block_idx-paivitys on vaarin~~ - EI, lane-
   tason vertailu golden-malliin nayttaa TAYDELLISEN tasmaavuuden
   jokaisen lohkon jalkeen, myos kolmannen (viimeisen).
4. ~~Keccak-ydin epaonnistuu SPESIFISESTI >=3 lohkolla~~ - EI, tama
   oli oman debug-metodologian virhe (katso Vaihe 3).
5. **LOYDETTY: vaara hajautusfunktion valinta oman pack_dk.sv:n
   suunnittelussa** - SHA3-512 kaytettiin SHAKE256:n sijaan.

## Opetus jatkoon

1. **FIPS 204:n H()-funktio ON SHAKE256** - EI SHA3-512. Tama
   koskee KAIKKIA tulevia Dilithium-tyon kohtia joissa H()-funktiota
   kaytetaan (esim. Sign-algoritmin oma `mu=H(tr||M)`,
   `rhoPrimePrime=H(K||rnd||mu)`, `c_tilde=H(mu||w1)` jne) -
   TARKISTETTAVA JOKAINEN erikseen `dilithium-py`:n omasta
   lahdekoodista, ALA OLETA SHA3-512:ta minkaan Dilithium-kontekstin
   H()-kutsun kohdalla.
2. **Kun vertaillaan RTL:n ulostuloa golden-arvoon, kayta AINA
   tiedostopohjaista `$fscanf+===`-menetelmaa** - ALA KOSKAAN
   kopioi `$display %h`:n tulostetta kasin Pythoniin ilman
   eksplisiittista tavujarjestyksen tarkistusta. Tama ITSESSAAN oli
   se metodologinen sudenkuoppa joka loi TAMAN koko tutkimuksen
   tarpeen.
3. **Kun jaettu, jo laajasti todistettu infrastruktuuri (esim.
   Keccak) alkaa nayttaa "epaonnistuvan" uudessa kayttokontekstissa,
   tarkista ENSIN oma UUSI koodi (kayttopaikan omat valinnat,
   parametrit, funktion valinta) ENNEN kuin epailet jaettua,
   aiemmin vankasti todistettua ydinta.** Kayttajan oma alkuperainen
   havainto ("kattavuusraja, ei satunnainen bugi") oli TAYSIN OIKEA -
   mutta se osoittautui koskevan OMAA UUTTA KOODIA (vaara
   funktiovalinta), ei jaettua ydinta.
