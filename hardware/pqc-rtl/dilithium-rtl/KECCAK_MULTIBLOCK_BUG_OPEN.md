# LOYDETTY AVOIN BUGI: pqc_keccak_absorb.sv (tai riippuvuus) epaonnistuu >=3 lohkolla

**Paivamaara:** 2026-07-19
**Vakavuus:** MERKITTAVA - vaikuttaa KAIKKIIN SHA3-256/SHA3-512/
SHAKE128/SHAKE256-kutsuihin joissa viesti tarvitsee 3 TAI USEAMPI
absorbointilohko.

## Loydon konteksti

DK4:n dk-pakkaus (tr=H(ek), SHA3-512 1952-tavuiselle ek:lle, tarvitsee
28 lohkoa RATE_BYTES=72:lla) epaonnistui - 64/4032 tavua eroaa
(TASMALLEEN tr:n oma koko).

## Kavennettu tarkasti

Systemaattinen kavennus paljasti:
- **1 lohko:** toimii oikein (kaikki aiemmat ML-KEM/Dilithium-kaytot,
  aina <=1 lohko - EI KOSKAAN paljastanut tata)
- **2 lohkoa:** toimii oikein (todennettu 100-tavuisella viestilla)
- **3 lohkoa:** EPAONNISTUU (todennettu 196-tavuisella viestilla)
- **4 lohkoa:** EPAONNISTUU (todennettu 268-tavuisella viestilla)
- **5 lohkoa:** EPAONNISTUU (todennettu 356-tavuisella viestilla)
- **28 lohkoa:** EPAONNISTUU (alkuperainen loydos, 1952-tavuinen ek)

**KRIITTINEN HAVAINTO:** kaikissa epaonnistuneissa tapauksissa (3+
lohkoa) RTL:n ulostulo ON TAYSIN TAVUJARJESTYKSELTAAN KAANNETTY
versio oikeasta tuloksesta (`rtl_bytes[::-1] == golden_bytes`,
vahvistettu Pythonilla jokaiselle epaonnistuneelle tapaukselle).

## Miksi tama ei loytynyt aiemmin

KAIKKI taman ISTUNNON aiemmat SHA3-256/512/SHAKE128/256-kaytot
(KeyGen, Decaps, Encaps, TAU-integraatio) kayttivat viesteja jotka
tarvitsivat AINA <=2 lohkoa (yleensa 1). Tama on ENSIMMAINEN kerta
kun 3+ lohkoa on tarvittu missaan taman projektin osassa - tama BUGI
ON OLLUT OLEMASSA KOKO AJAN, mutta ei koskaan trigannut.

## Tutkitut, EI syyllisiksi todetut osat

- `pqc_keccak_f1600.sv`: round_idx resetoituu oikein JOKA start-
  pulssilla (rivi 99: `round_idx<=0` S_IDLE:ssa start:in yhteydessa) -
  tama toimii OIKEIN riippumatta MONTAKO kertaa f1600:aa kutsutaan
  perakkain.
- `pqc_keccak_squeeze.sv`: EI OSALLISTU tahan bugiin - squeeze lukee
  VAIN LOPULLISESTA absorboidusta tilasta, EI PITAISI riippua siita
  montako absorbointilohkoa edelsi. (Ei viela todistettu 100%
  varmasti, mutta rakenteellisesti EI PITAISI olla syyllinen.)
- `pqc_keccak_absorb.sv`:n oma silmukkalogiikka (block_idx-laskuri,
  acc_state-paivitys): TEOREETTINEN TARKASTELU EI LOYTANYT ilmeista
  virhetta - block_idx nollataan oikein, acc_state paivittyy
  nonblocking-sijoituksilla oikeassa jarjestyksessa. TAMA VAATII
  KUITENKIN empiirista debug-jaljitysta (signaalitason tulostusta
  JOKAISEN lohkon jalkeen) jota EI EHDITTY tehda tassa istunnossa.

## EI VIELA LOYDETTY: tarkka juurisyy

Vaadittava seuraava askel: lisaa debug-tulostus pqc_keccak_absorb.sv:n
SISALLE (tai testipenkkiin joka kayttaa hierarkkista signaalinimea
`dut.acc_state`, `dut.block_idx`) JOKAISEN blokin jalkeen 3+ lohkon
tapauksessa, ja vertaa VALIARVOJA (acc_state kunkin permutaation
jalkeen) golden-Python-mallin OMIIN valivaiheisiin (keccak_golden.py:n
oma Keccak-p-permutaatio, ajettuna askel askeleelta).

## Vaikutus koko projektiin

- **Dilithium DK4 (dk-pakkaus):** ESTETTY - tr=H(ek) vaatii 28 lohkoa.
- **ML-KEM:** EI VALITONTA VAIKUTUSTA havaittu (kaikki nykyiset kaytot
  <=2 lohkoa), MUTTA jos TULEVA tyo (esim. suurempi viesti jollekin
  hajautusfunktiolle) tarvitsisi 3+ lohkoa, TAMA SAMA BUGI iskisi
  siihenkin.
- **CI:** olemassa olevat testit EIVAT havaitse tata (kaikki kayttavat
  <=2 lohkon viesteja) - CI:n oma regressiosuoja EI KATA tata
  skenaariota. HARKITTAVA: lisaa CI-testi joka kayttaa NIMENOMAAN 3+
  lohkon viestia SHA3-256/512:lle, kun juurisyy on loydetty ja
  korjattu.
