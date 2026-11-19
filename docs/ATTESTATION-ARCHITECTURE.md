# Laitteiden attestaatio: arkkitehtuuri

**Kirjattu:** 2026-11-19. Suuntapäätös 2026-11-16 (`PROJECT_STATUS_AND_DIRECTION.md`).
Tasot ja todentajan vastaukset: [`ATTESTATION-LEVELS.md`](ATTESTATION-LEVELS.md).

## Tavoite ja rajaus

Käyttäjän omat laitteet todistavat tilansa erilliselle todentajalle. Tavoite
on C (identiteetti ja käynnistysketju), mutta jokainen laite todennetaan
vain siltä osin kuin sen laitteisto sen sallii, ja vastaus sanoo sen.

Ei tavoitteena: muiden käyttäjien laitteet, valmistajan juuriin ankkuroitu
laivastohallinta, Play Integrity -tyyppinen sovelluseheys.

## Roolit

| Laite | Rooli | A | B | Q |
|---|---|---|---|---|
| Raspberry Pi 2 | Todentaja (Trust Server) | – | – | – |
| Samsung Galaxy S24 | Ensisijainen attestoija | TEE/StrongBox-avainattestaatio | Verified boot -tila, bootloaderin lukitus | ML-DSA-65 Android 17 Keystoressa; säilytystaso mitataan |
| Samsung Galaxy S21 | Testiattestoija | TEE-avainattestaatio | Verified boot -tila | ML-DSA-65 ohjelmistona |
| Raspberry Pi 5 | Linux-attestoija | swtpm (kehitys), myöhemmin TPM-moduuli | **`UNSUPPORTED`** (rakenteellinen) | ML-DSA-65 ohjelmistona (liboqs) |
| Lenovo IdeaCentre Mini | Kehityskone; myöhempi vaihtoehto UEFI Measured Bootille | – | – | – |

### Pi 2: todentaja

Todentaja ei todista itseään, joten se ei tarvitse TPM:ää. Se pidetään
erillään päivittäisestä koneesta. Tehtävät: nonce, rekisteröinti (käsin
hyväksytty), todisteiden tarkistus, käytännön soveltaminen, hash-ketjutettu
loki päätöksistä. Rekisteröidyt avaimet ja käytäntö ovat todentajan
luottamuksen perusta: niiden muuttaminen kirjataan lokiin.

### S24: ensisijainen attestoija

S24 sai Android 17:n (One UI 9) lokakuussa 2026, ja Samsung lupaa sarjalle
seitsemän vuotta päivityksiä. Siksi se on tuotannon attestoija, S21 ei.

Todisteet:
- Android Key Attestation: avainpari luodaan Keystoreen todentajan noncella
  (attestation challenge). Varmenneketjun lehtivarmenteen KeyDescription-
  laajennus sisältää `attestationSecurityLevel` (TEE/StrongBox) ja
  `RootOfTrust` (verifiedBootState, deviceLocked, verifiedBootKey) sekä
  päivitystasot.
- Ketju tarkistetaan Googlen attestaatiojuuriin (sekä vanha että uusi juuri,
  `https://android.googleapis.com/attestation/root`) ja revokaatiolistaan.
- Rekisteröinnissä talletetaan lehtiavaimen ja `verifiedBootKey`:n tunniste;
  myöhemmät vastaukset verrataan niihin.
- ML-DSA-65: Android 17:n Keystore tukee sitä. **Avoin:** onko avain S24:llä
  TEE:ssä/StrongBoxissa vai ohjelmistossa, ja onko KeyMintin
  attestaatioketju klassinen vai PQC. Mitataan laitteelta, ei oleteta.
  Q:n tulos ilmoittaa säilytystason.

**B:n tarkka sisältö Androidilla.** Verified boot -tila tarkoittaa, että
käynnistysketju tarkisti boot- ja järjestelmäosioiden allekirjoitukset
(dm-verity) laitteen valmistajan avainta vasten ja bootloader on lukittu.
Se ei tarkoita:
- sovellusten, käyttäjädatan tai ajonaikaisen tilan mittaamista;
- suojaa haavoittuvuuksilta, joita laitteen päivitystaso ei korjaa;
- että jokainen järjestelmäkomponentti olisi mitattu erikseen: väite koskee
  verifioitua käynnistysketjua kokonaisuutena, sellaisena kuin TEE sen
  raportoi.

### S21: testiattestoija

Android 15 (One UI 7) oli viimeinen iso päivitys, ja tietoturvapäivitykset
päättyivät tammikuussa 2026. A ja B toimivat samoin kuin S24:llä, mutta
klassisella juurella ja vanhenevalla TEE:llä. Käyttö: kehitys ja
negatiivikontrollit (vanha päivitystaso käytännössä). Ei tuotantoon.

### Pi 5: Linux-attestoija, A ilman B:tä

**Rakenteellinen rajoitus, ei väliaikainen puute.** Raspberry Pi:n virallinen
bootloader tukee allekirjoitettua käynnistystä mutta ei mittaa käynnistystä
TPM:ään. TPM-moduulin kanssa PCR 0–7 jäävät nolliksi. Mittauksen voi aloittaa
U-Bootissa tai kernelissä (IMA), mutta silloin ensimmäinen mittaaja on
mittaamatonta ohjelmistoa. TPM-moduuli antaa Pi 5:lle vahvan A:n; B on aina
`UNSUPPORTED`.

### Lenovo: myöhempi vaihtoehto

Koneessa on TPM ja UEFI Measured Boot (PCR 0–7), mutta se ajaa Windowsia ja
Linuxia WSL:ssä, joka ei näe TPM:ää. Linux-puolen B olisi saatavissa vain
Linuxilla suoraan raudalla. Päätös myöhemmin, kun S24- ja swtpm-vaiheet
toimivat.

## swtpm

`swtpm` on kehitys- ja CI-ympäristö. Sen avaimet ovat ohjelmistossa, joten
swtpm:llä saatu A ei ole laitteistoon ankkuroitu. Todentajan käytäntö
tunnistaa swtpm:n (rekisteröinnissä merkitty) eikä hyväksy sitä
tuotantolaitteelle.

## Nykyinen Trust Server ei täytä tätä (havaittu 2026-11-19)

`pi2_trust_server/core/trustcore/server.py`:
1. **TPM-quoten allekirjoitusta ei tarkisteta.** Asiakas lähettää
   `tpm_quote`-kentän, mutta palvelin ei käytä sitä. PCR-arvot ovat
   ML-DSA-allekirjoitetun viestin sisällä, ja ML-DSA-avain on ohjelmistossa.
   Laite voi siis ilmoittaa minkä tahansa PCR-arvot. Nykyinen PASS on
   käytännössä "ohjelmistoavaimen haltija allekirjoitti viestin".
2. **Puuttuva PCR ohitetaan:** jos PCR puuttuu vastauksesta, vertailu
   ohitetaan hiljaa.
3. **Ilman PCR-lähtötilaa PCR:iä ei verrata lainkaan,** ja vastaus on silti PASS.
4. **Ensimmäinen näkeminen rekisteröi automaattisesti** (`TRUSTCORE_ALLOW_FIRST_SEEN`
   oletus 1).
5. **Asiakas jatkaa ilman quotea,** jos `tpm2_quote` epäonnistuu (`quote = {}`).

CI-testi "TPM+PQC päästä päähän" todentaa siis, että viesti kulkee ja
allekirjoitus täsmää, ei TPM-attestaatiota. Korjaus on vaihe 1 alla.
Kirjattu `KORJAUSLISTA.md`:hen (A16).

## Vaiheet

Jokainen vaihe on oma PR, ja sen hyväksymiskriteerit kirjataan ennen koodia.

1. **Todentajan ydin `ATTESTATION-LEVELS.md`:n mukaiseksi** (swtpm, CI):
   väitekohtaiset tulokset, TPM-quoten allekirjoitus ja nonce tarkistetaan
   AK:ta vasten, PCR-digest quotesta, käsin hyväksytty rekisteröinti,
   negatiivikontrollit jokaiselle säännölle.
2. **Android-todisteiden tarkistus todentajalla:** varmenneketjun ja
   KeyDescriptionin jäsennys, Googlen juuret, revokaatio. Testataan
   tallennetuilla todistesarjoilla ennen puhelinta.
3. **Android-sovellus** (Kotlin, rakennetaan CI:ssä): nonce, Keystore-avain
   challengella, ML-DSA-65, lähetys. Ensin S21:llä, sitten S24:llä.
4. **ML-DSA:n säilytystason mittaus S24:llä** (Android 17 Keystore).
5. **Pi 5:n A fyysisellä TPM:llä** (moduulin hankinta tässä vaiheessa) ja
   Lenovo/UEFI-päätös.

## Puhelimen tietoturva asennettaessa

Oman sovelluksen asentaminen (sivulataus tai `adb install`) ei heikennä
alustan tietoturvaa, kun:
- bootloaderia ei avata eikä laitetta rootata. Samsungilla bootloaderin
  avaaminen laukaisee pysyvästi Knox-takuubitin, ja attestaatio raportoisi
  laitteen avoimeksi (B = `FAILED`) pysyvästi;
- Samsungin Auto Blocker (Asetukset → Tietoturva ja yksityisyys → Auto
  Blocker) kytketään pois vain asennuksen ajaksi ja takaisin päälle sen
  jälkeen; samoin USB-virheenkorjaus;
- sovellus pyytää vain verkko-oikeuden. Keystore-avaimet eivät ole
  sovelluksesta poimittavissa.
