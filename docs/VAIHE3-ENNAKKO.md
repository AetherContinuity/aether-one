# Vaihe 3: Android-sovellus ja ensimmäinen mittaus oikeilla laitteilla (ennakkoon)

**Kirjattu:** 2026-11-20, ennen yhtään vaiheen 3 koodiriviä ja ennen yhtään
laiteajoa. Sitova: `docs/ATTESTATION-LEVELS.md`, todistemalli
`docs/VAIHE2-ENNAKKO.md`. Poikkeamat: `VAIHE3-POIKKEAMA-N.md`. Tulokset:
`VAIHE3-TULOS.md` (kirjoitetaan vasta laiteajojen jälkeen).

Vaihe jakautuu kahteen osaan: **3a** sovellus ja sen CI-todennus (ei
laitetta), **3b** laiteajot S21:llä ja S24:llä (omistaja asentaa ja ajaa).

## Sovellus (3a)

- Kotlin, minSdk 31 (Android 12: `setAttestKeyAlias`), yksi näkymä, vain
  `INTERNET`-oikeus. Rakennetaan CI:ssä; APK on CI:n artefakti.
- **Rekisteröinti:** omistaja syöttää `admin.py android-nonce`:n noncen.
  Sovellus luo K:n (EC P-256, challenge = nonce): `PURPOSE_ATTEST_KEY`, jos
  `FEATURE_KEYSTORE_APP_ATTEST_KEY` on tuettu, muuten `PURPOSE_SIGN`
  (tila `signed`). Ensin StrongBox, sen epäonnistuessa TEE; valinta
  kirjataan. Sovellus luo ML-DSA-65-avaimen ohjelmistona (BouncyCastle),
  salattuna Keystoren AES-avaimella sovelluksen yksityiseen tiedostoon.
  Vienti: JSON jaetaan jakovalikosta; omistaja siirtää sen Pi 2:lle.
- **Attestaatio:** `GET /nonce`, tuore avain challengella, tilassa
  `attest_key` `setAttestKeyAlias(K)`. Jos Keystore palauttaa vain lehden,
  sovellus liittää K:n ketjun perään, ja tämä kirjataan diagnostiikkaan.
  Tuore avain poistetaan heti. ML-DSA allekirjoittaa TC02-viestin
  (`evidence_hash` kattaa ketjun). Lähetys CBOR:na `POST /verify`. Tulos
  näytetään väite kerrallaan, ilman yhteistä tilaa.
- **Diagnostiikka:** Android-versio, tietoturvapäivitystaso, KeyMint-
  ominaisuuslippu, attest key -tuki, StrongBox-tuki, palautetun ketjun
  pituus. Ei laitetunnisteita (IMEI, sarjanumero) eikä ID-attestaatiota.

## Hyväksymiskriteerit 3a (CI, ennen laitetta)

**S1 Tavutason yhteensopivuus todentajan kanssa.** Python generoi kultaiset
vektorit (TC02-viesti, `evidence_hash`, `k_signed_message`, CBOR-paketti)
kiinteistä syötteistä. Kotlinin JVM-yksikkötesti tuottaa samat tavut.
Negatiivikontrolli: yksi muutettu syötetavu → eri tavut.

**S2 ML-DSA ristiin.** Kotlin (BouncyCastle) allekirjoittaa; Python
(liboqs) verifioi CI:ssä. Turmeltu allekirjoitus ei verifioidu.

**S3 Rakennus.** `assembleRelease` CI:ssä, allekirjoitettu pysyvällä
avaimella (GitHub Actions -salaisuus), APK:n sha256 tulostetaan lokiin.
Lint ja yksikkötestit vihreinä.

**S4 Ei ylimääräisiä oikeuksia.** CI tarkistaa koostetusta manifestista
(`aapt2 dump permissions`): ainoa oikeus on `INTERNET`.

## Laiteajot (3b): hypoteesit ennakkoon

Ajojärjestys: S21 ensin, sitten S24. Kummallakin: rekisteröinti, kolme
attestaatiota, negatiivikontrollit. Laitteen todisteita (ketjuja) **ei
commitoida** julkiseen repoon (RKP-varmenteet ovat laitekohtaisia);
tulokseen kirjataan jäsennetyt kentät ja väitteiden tulokset.

| # | Hypoteesi | Hylätään, jos |
|---|---|---|
| H1 | S24 tukee app attest keytä → tila `attest_key` | ominaisuuslippu puuttuu tai avaimen luonti kaatuu |
| H2 | S21:n tila on ennalta tuntematon | (ei hylkäyssääntöä; kirjataan) |
| H3 | S24:n ketju päättyy uuteen ECDSA P-384 -juureen (RKP) | ketju päättyy RSA-juureen |
| H4 | S24: A `VERIFIED`, B `VERIFIED` | jompikumpi muu kuin `VERIFIED` |
| H5 | Samsung raportoi `vendorPatchLevel`/`bootPatchLevel` = 0 kuten 2019-sukupolvi → P `PARTIAL` | S24 raportoi ne nollasta poikkeavina (H5 hylätään; P voi olla `VERIFIED`) |
| H6 | S21: `osPatchLevel` ≤ 202601 (tuki päättyi) | suurempi arvo |
| H7 | Q `VERIFIED`, perustelussa säilytystaso "ohjelmisto" | muu tulos |

Hypoteesit eivät muuta väitesääntöjä. Jos tulos poikkeaa, kirjataan miksi;
sääntöjä ei säädetä tuloksen mukaan.

## Negatiivikontrollit laitteella (3b)

| Tapaus | Odotettu |
|---|---|
| sama paketti lähetetään kahdesti | toinen: kaikki `UNKNOWN` (nonce käytetty) |
| S21:n todiste S24:n device_id:llä | A `FAILED` |
| paketin ketjusta yksi tavu muutettu (sovelluksen testipainike) | A `FAILED` tai `UNKNOWN`, ei `VERIFIED` |
| attestaatio ennen rekisteröintiä | kaikki `UNKNOWN` |

Avatun bootloaderin kontrollia ei ajeta oikealla laitteella: se laukaisisi
Samsungin Knox-takuubitin pysyvästi. Se on katettu synteettisesti (vaihe 2).

## Turvallisuus asennuksessa

`ATTESTATION-ARCHITECTURE.md`, "Puhelimen tietoturva asennettaessa": ei
bootloaderin avausta eikä roottausta; Auto Blocker pois vain asennuksen
ajaksi; vain `INTERNET`-oikeus. Pi 2:n osoite on lähiverkossa ja yhteys
HTTP:tä; todisteen eheys ei riipu kuljetuksesta (allekirjoitukset, nonce),
mutta välissä oleva voi estää vastauksen. Tämä kirjataan, ei korjata tässä
vaiheessa.

## Ei tässä vaiheessa

ML-DSA Android 17 Keystoressa (vaihe 4), käytäntötiedosto, Play-jakelu,
automaattinen ajastus.
