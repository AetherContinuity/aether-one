# Vaihe 2: Android-todisteen tarkistus — hyväksymiskriteerit (ennakkoon)

**Kirjattu:** 2026-11-20, ennen yhtään vaiheen 2 koodimuutosta.
Sitova lähde: `docs/ATTESTATION-LEVELS.md`. Rakenne: vaihe 1 (`verifier.evaluate`).
Poikkeamat näistä kriteereistä tuloksen jälkeen: `VAIHE2-POIKKEAMA-N.md`.

## Rajaus

Todentajan puoli. Ei puhelinta eikä sovellusta (vaihe 3). Testit ajetaan
tallennetuilla ja synteettisillä varmenneketjuilla. **CI:ssä yksikään oikea
laite ei saa B:lle `VERIFIED`:iä**: oikeat tallennetut ketjut ovat vuosilta
2019–2025 eivätkä ole sidottuja tämän todentajan nonceen. B:n `VERIFIED`
oikealla laitteella todennetaan ensimmäisen kerran vaiheessa 3 (S21, S24).

## Todistemalli (sitoo vaiheen 3 sovellusta)

**Rekisteröinti.** Puhelin luo Keystoreen pysyvän avaimen K (EC P-256)
rekisteröintinoncella challengena. Ensisijaisesti K:n tarkoitus on vain
`ATTEST_KEY` (KeyMint 2+, `setAttestKeyAlias`), muuten `SIGN`. Omistaja vie
K:n varmenneketjun ja ML-DSA-65-julkisen avaimen todentajalle käsin
(`admin.py enroll`, sama kuin vaihe 1). Rekisteröinti tallettaa K:n julkisen
avaimen, turvatason (TEE/StrongBox), `verifiedBootKey`:n ja tilan
(`attest_key` | `signed`).

**Pyyntö.** Puhelin luo tuoreen avaimen, challenge = todentajan nonce.
- Tila `attest_key`: TEE allekirjoittaa tuoreen avaimen varmenteen K:lla.
  Ketju: tuore lehti → K → … → Googlen juuri.
- Tila `signed`: tuore ketju Googlen juureen; lisäksi K:n allekirjoitus
  viestistä nonce ‖ SHA-256(tuoreen ketjun DER-varmenteet).

ML-DSA-65-allekirjoitus kattaa laitteen tunnisteen, noncen ja koko
todisteen tiivisteen (kuten vaiheessa 1).

## Hyväksymiskriteerit

Vaihe 2 on valmis, kun kaikki pätevät CI:ssä.

**K1 Ketju.** Jokainen varmenne on edellisen julkaisijan allekirjoittama
(pareittain, Googlen esimerkin mukaisesti, ei PKIX-polkua), voimassa
todentajan ajanhetkellä (testeissä annettava aika), ja juuri on kiinnitetyssä
juurijoukossa. Juurijoukko: vanha RSA-juuri ja helmikuussa 2026 käyttöön
otettu ECDSA P-384 -juuri, tiedostossa sha256-sormenjälkineen ja lähteineen.

**K2 Juuren seuranta.** CI-job hakee `https://android.googleapis.com/attestation/root`
ja vertaa kiinnitettyyn joukkoon. Ero kaataa jobin (juuri vaihtui, päivitys PR:nä).

**K3 Revokaatio.** Jokaisen varmenteen sarjanumero tarkistetaan Googlen
tilalistaa (`/attestation/status`) vasten. Lista haetaan todentajalle;
yli 24 h vanha tai puuttuva lista → A enintään `PARTIAL` ("revokaatiotila
tuntematon"). REVOKED tai SUSPENDED → A `FAILED`.

**K4 KeyDescriptionin sijainti.** Tilassa `signed` laajennus luetaan
juurta lähimmästä sen sisältävästä varmenteesta (Googlen ohje). Tilassa
`attest_key` lehden laajennus hyväksytään vain, jos lehden julkaisijan
(K) oma KeyDescription sisältää tarkoituksen `ATTEST_KEY` (7) eikä
`SIGN`-tarkoitusta. Muuten lehden laajennukseen ei luoteta.

**K5 Väitteet.**

| Väite | `VERIFIED` kun | Muuten |
|---|---|---|
| A | ketju K1–K3 kunnossa; K = rekisteröity; K:n turvataso TEE/StrongBox ja ≥ rekisteröity; challenge = nonce; tila `signed`: K:n allekirjoitus täsmää | turvataso Software, vieras juuri, rikkinäinen allekirjoitus, vanhentunut varmenne, väärä K tai challenge → `FAILED`; jäsennysvirhe → `UNKNOWN`; revokaatiolista puuttuu → `PARTIAL` |
| B | tila `attest_key`; laitteistossa valvotun listan RootOfTrust: `verifiedBootState = Verified`, `deviceLocked = true`, `verifiedBootKey` = rekisteröity | tila `signed` → enintään `PARTIAL` (ketjua ei ole sidottu K:hon TEE:ssä); lukitsematon, muu kuin Verified tai eri `verifiedBootKey` → `FAILED`; RootOfTrust puuttuu → `UNKNOWN` |
| P | tila `attest_key`; `osPatchLevel`, `vendorPatchLevel`, `bootPatchLevel` laitteistossa valvotussa listassa; arvot perustelussa | osa puuttuu → `PARTIAL` (puuttuvat nimetään); vain ohjelmistossa valvotussa listassa tai ei lainkaan → `UNKNOWN`; tila `signed` → enintään `PARTIAL` |
| Q | kuten vaihe 1; säilytystaso rekisteröinnistä (vaiheeseen 4 asti "ohjelmisto") | kuten vaihe 1 |

B:n perustelu nimeää rajauksen (`ATTESTATION-ARCHITECTURE.md`: verifioitu
käynnistysketju kokonaisuutena TEE:n raportoimana, ei ajonaikaista tilaa).
P:n ikää ei arvioida väitteessä; se on käytännön asia.

**K6 Rekisteröinti kieltäytyy,** jos K:n ketju ei täytä K1:tä, turvataso on
Software, `deviceLocked` ei ole tosi, `verifiedBootState` ei ole Verified tai
challenge ei ole rekisteröintinonce.

**K7 Ulkoinen mittapuu: Googlen jäsennin.** `google/android-key-attestation`
(commit f9846cd, sha256 kiinnitetty) ajetaan CI:ssä samoille ketjuille.
Kentät attestationVersion, attestationSecurityLevel, keymasterVersion,
keymasterSecurityLevel, attestationChallenge, RootOfTrust (4 kenttää),
osVersion, patch-tasot (3), purpose ja algorithm vertaillaan omaan
jäsentimeen. Yksikin ero kaataa testin. Vertailijan negatiivikontrolli:
yksi tarkoituksella muutettu odotusarvo kaatuu.

Testiketjut:
- Googlen testiresurssit (4 ketjua: EC/RSA × TEE/StrongBox).
- GrapheneOS Auditorin näytteet Samsung-laitteilta (`dbaxa/AttestationSamples`,
  commit b7f2d29; 28 mallia, 2019, vanha juuri). Ketjut tarkistetaan
  aikana, jolloin ne olivat voimassa.
- Synteettiset ketjut (K8). Myös nämä ajetaan Googlen jäsentimellä,
  jotta oma kooderi ei ole oman jäsentimen ainoa tuomari.

**K8 Synteettiset ketjut.** Testityökalu luo ketjuja testijuuren alle.
Testijuuri on vain testien luottamusjoukossa; tuotantojoukon lataaja
kieltäytyy siitä. Positiivinen tapaus: tila `attest_key`, lukittu, Verified,
kaikki patch-tasot → A, B, P, Q `VERIFIED`.

**K9 Negatiivikontrollit.** Jokainen ajetaan CI:ssä. Mikään ei saa antaa
`VERIFIED`:iä mainitulle väitteelle:

| Tapaus | Odotettu |
|---|---|
| challenge ≠ nonce | A, B, P `FAILED` |
| `deviceLocked = false` | B `FAILED` |
| `verifiedBootState` Unverified / SelfSigned / Failed | B `FAILED` |
| `verifiedBootKey` ≠ rekisteröity | B `FAILED` |
| `attestationSecurityLevel` Software | A `FAILED` |
| ketjun allekirjoitus turmeltu | A `FAILED` |
| synteettinen ketju tuotantojuurijoukkoa vasten | A `FAILED` |
| välivarmenne revokoitu tilalistassa | A `FAILED` |
| tilalista puuttuu tai yli 24 h vanha | A `PARTIAL` |
| välivarmenne vanhentunut annettuna hetkenä | A `FAILED` |
| K ≠ rekisteröity | A `FAILED` |
| väärennetty lehti SIGN-tarkoituksen avaimella (K4) | B, P `FAILED` |
| tila `signed`, muuten ehjä | B, P `PARTIAL` |
| tila `signed`, K:n allekirjoitus turmeltu | A `FAILED` |
| RootOfTrust puuttuu | B `UNKNOWN` |
| patch-tasot puuttuvat / osa puuttuu | P `UNKNOWN` / `PARTIAL` |
| katkaistu tai jäsentymätön DER | A, B, P `UNKNOWN` |
| rekisteröimätön laite | kaikki `UNKNOWN` |
| rekisteröinti: Software, lukitsematon, vieras juuri, väärä challenge | kieltäytyy |

**K10 Riippuvuus.** X.509-rakenteet ja allekirjoitukset: pyca `cryptography`.
KeyDescription-jäsennin on oma (vakiokirjasto), koska se mitataan
Googlen jäsennintä vasten (K7). Linux-polun (vaihe 1) testit pysyvät
muuttumattomina ja vihreinä.

## Ei tässä vaiheessa

Sovellus ja oikeat laitteet (vaihe 3), ML-DSA:n säilytystason mittaus
(vaihe 4), Samsung Knox -attestaatio, ID-attestaatio (vaatii
etuoikeutetun luvan), käytäntötiedosto (hyväksymisrajat).
