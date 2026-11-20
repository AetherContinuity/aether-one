# Vaihe 1: poikkeama 1 — PCR-kontrollin toteutusvirhe ja lisäykset

**Kirjattu:** 2026-11-20. Kriteerit: `docs/VAIHE1-ENNAKKO.md` (commit b0161d6).
Kriteereitä ei muutettu. Tämä tiedosto kirjaa, mikä mittauksessa poikkesi
ensimmäisestä toteutuksesta ja mitä lisättiin.

## 1. K8 "PCR-arvo muutettu": ensimmäinen toteutus ei mitannut mitään

Ensimmäinen ajo: 10/11 tapausta odotetusti. "Muutettu PCR" antoi A `PARTIAL`,
odotettu `FAILED`.

Syy oli testissä, ei todentajassa. Testi käänsi `tpm2_quote -o` -tiedoston
viimeisen tavun. tpm2-tools sarjallistaa kiinteäkokoiset C-rakenteet
(TPML_PCR_SELECTION 132 tavua, TPML_DIGEST 16 paikkaa à 66 tavua); 9 PCR:n
tiedosto on 1200 tavua, joista käytössä noin 680. Viimeinen tavu on täytettä,
jota `tpm2_checkquote` ei lue. Käsin tarkistettu: täytteen kääntäminen
(tavut 1199 ja 1100) → `tpm2_checkquote` rc=0.

Korjaus: testi kääntää PCR0:n arvon ensimmäisen tavun (siirtymä 142) ja
tarkistaa ensin rakenteen (valintojen määrä 1, pankki sha256, listoja ≥ 1,
digestejä ≥ 1, koko 32). Jos tiedostomuoto muuttuu, testi kaatuu eikä
turmelu ohjaudu täytteeseen. Korjattu ajo: A `FAILED`.

Tulkinta: kontrolli, joka olisi mennyt läpi hiljaa, jos odotus olisi ollut
väärä. Täsmälleen se tapaus, jota "mittarin täytyy pystyä epäonnistumaan"
varten on.

Seuraus todentajalle: ei muutosta. `quote_hash` kattaa koko tiedoston
täytteineen, joten täytteen muuttaminen ilman uudelleenallekirjoitusta
kaataa Q:n.

## 2. Toteutusvalinnat, joita kriteerit eivät kiinnittäneet

- **AK:n attribuutit binääristä.** K2 vaatii, että rekisteröinti kieltäytyy
  rajoittamattomasta AK:sta. PEM ei sisällä TPM-attribuutteja, ja
  `tpm2_readpublic`-teksti on pelkkä väite. `admin.py` jäsentää TSS-muotoisen
  TPM2B_PUBLIC:n (`tpm_public.py`), lukee `objectAttributes`-kentän ja
  muodostaa todentajan PEM:n samasta rakenteesta. Ulkoinen mittapuu:
  muodostettu PEM on tavu tavulta sama kuin `tpm2_readpublic -f pem`
  (tarkistetaan `test_vaihe1.py`:ssä joka ajossa). Lisäksi kielletään
  `decrypt`-attribuutti.
- **`quote_hash`** = SHA-256(`"TCQ1"` ‖ len‖msg ‖ len‖sig ‖ len‖pcrs),
  pituudet 4-tavuisina big-endian-kokonaislukuina. Erotinmerkki ei sovi
  binäärikentille.
- **Allekirjoitettu viesti TC02** (`make_attestation_message`). TC01
  (`make_signed_message`) poistettu; sitä käyttivät vain poistettu `/enroll`
  ja sen testi.

## 3. Lisätyt tarkistukset (kriteerien lisäksi)

| Tapaus | Tulos |
|---|---|
| quote vaihdettu toiseen, ML-DSA:ta ei allekirjoitettu uudelleen | A `FAILED`, Q `FAILED` (K7: allekirjoitus kattaa quoten) |
| vajaa rekisteröintivienti (AK puuttuu) | rekisteröinti kieltäytyy |
| `install.sh` ilman tpm2-toolsia (CI) | asennus keskeytyy |
| rekisteröimätön laite HTTP:n yli (`test_client_e2e.py`) | kaikki `UNKNOWN` |

## 4. Kuluttajapuoli

Pi 5:n `aether_relay.py` tallensi `/verify`-vastauksen `status`-kentän ja
näytti käyttöliittymässä vihreän PASS-tilan. Nyt `/attestation` palauttaa
väitteet (`claims`) ja `status`-kentässä tiivistelmätekstin
("A:PARTIAL B:UNSUPPORTED P:UNSUPPORTED Q:VERIFIED"). Käyttöliittymällä ei
ole PASS-väriä. Todentajan tavoittamattomuus on `UNKNOWN`, ei `FAIL`.
