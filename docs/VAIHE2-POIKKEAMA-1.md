# Vaihe 2: poikkeama 1 — oikeiden laitteiden poikkeamat ja mittapuun löydös

**Kirjattu:** 2026-11-20. Kriteerit: `docs/VAIHE2-ENNAKKO.md` (commit 57c9594).
Kriteerien väitesäännöt eivät muuttuneet. Tämä tiedosto kirjaa, mitä
ulkoinen mittapuu ja oikeat ketjut paljastivat ja mitä toteutukseen siksi
lisättiin.

## 1. Googlen jäsennin paljasti virheen P-väitteessä

Seitsemän Samsung-laitetta (Galaxy S10, S10+, Note10, Note10+ US, A70,
Tab A; Auditor-näytteet 2019) raportoi `vendorPatchLevel = 0` ja
`bootPatchLevel = 0` laitteistossa valvotussa listassa. Googlen jäsennin
hylkää nämä tietueet (`IllegalArgumentException`). Oma todentaja olisi
antanut P:lle `VERIFIED` arvolla 0.

Korjaus: arvo 0 = tasoa ei ilmoitettu → P `PARTIAL`, ja perustelu nimeää
kentän ("vendorPatchLevel (=0)"). Synteettinen tapaus lisätty K9:n
taulukkoon.

**Seuraus S21:lle ja S24:lle:** jos uudemmat Samsungit raportoivat samoin,
P on niillä `PARTIAL` eikä `VERIFIED`. Mitataan vaiheessa 3. Ei oleteta
kumpaankaan suuntaan.

## 2. Vertailusäännöt, joita kriteerit eivät kiinnittäneet

- Googlen jäsentimen hylkäys hyväksytään vain, jos omassa tietueessa on
  patch-taso 0. Muu Googlen virhe on ero. Vertailijan itsetesti tarkistaa
  molemmat: muutettu arvo kaatuu, ja Googlen hylkäys ilman 0-tasoa kaatuu.
- `verifiedBootHash`: oma `None` (kenttä puuttuu, attestaatioversio < 3)
  ≡ Googlen `''`.
- Patch-päivämäärät: Google normalisoi (kuukausi 00 → 01, päivä 00 tai
  puuttuva → 01). Vertailu: vuosi ja kuukausi aina, päivä vain kun oma
  raaka-arvo on 8-numeroinen eikä päivä ole 00.

Tulos CI:ssä: 113 KeyDescription-tietuetta (4 Googlen ketjua, 89 Auditor-
ketjua, 11 synteettistä), 0 eroa, 7 tunnettua hylkäystä (yllä).

## 3. Oikeiden laitteiden DER-poikkeamat, jotka sallitaan

| Poikkeama | Laite | Käsittely |
|---|---|---|
| `ecdsa-with-SHA256` + NULL-parametri (RFC 5758: puuttuva) | Googlen StrongBox-testiketju | Sallitaan, kirjataan A:n perusteluun. Syy omaan X.509-jäsentimeen: `cryptography` hylkää varmenteen. |
| `deviceLocked` = 0x01 (BER), DER vaatii 0xFF | Pixel 3 / 3 XL StrongBox (Titan M) | Yksi tavu, ≠ 0 = tosi. Googlen jäsennin hyväksyy. |
| Lehden julkaisijanimi ≠ julkaisijan nimi (title puuttuu) | Huawei AUM-L29, Xiaomi Pocophone F1 | Allekirjoitus ratkaisee (kuten Googlen esimerkki), ero kirjataan huomioksi. |

Oma X.509-jäsennin vastaa `cryptography`a kaikissa 336 varmenteessa,
jotka `cryptography` jäsentää (tbs, allekirjoitus, sarjanumero, nimet,
julkinen avain, voimassaolo, algoritmi). Lisäksi se jäsentää 12, joita
`cryptography` ei jäsennä.

## 4. Testiaineiston havainnot

- Googlen TEE-testiketjut päättyvät Googlen RSA-juureen (tuotantoavain);
  vain StrongBox-ketjujen juuri (`e35d38c6897d47e8`) on tuotannon
  ulkopuolella. Ensimmäinen testiversio oletti kaikki neljä vieraiksi;
  odotus valitaan nyt juuren avaimen mukaan.
- Auditorin 2016-juuri (vanhentunut 2026-05-24) käyttää samaa RSA-avainta
  kuin kiinnitetty 2022-juuri. Ankkuri on kiinnitetty avain; sen oman
  varmenteen voimassaoloa ei tarkisteta (RFC 5280 6.1.1 d). Ketjun
  varmenteiden voimassaolo tarkistetaan.
- "Välivarmenne vanhentunut" -kontrolli kaatui ensin lehteen, koska kaikki
  synteettiset varmenteet vanhenivat samana päivänä. Korjattu: välivarmenne
  vanhenee 30 päivässä, ja testi tarkistaa syyn ("varmenne 2").

## 5. Juuret

Haettu `https://android.googleapis.com/attestation/root` GitHub Actionsissa
(commit fb50b29), koska työtila ei tavoita osoitetta. Kaksi juurta: RSA 4096
(`serialNumber=f92009e853b6b045`, 2022–2042) ja ECDSA P-384 "Key Attestation
CA1" (2025–2035). Juurten seurantajob vertaa joka ajossa.

## 6. Ei vielä todennettu

B `VERIFIED` oikealla laitteella, uuden ECDSA-juuren ketju (yhtään ei ole
tallennettuna), attest key -tuki S21:llä ja S24:llä: vaihe 3.
