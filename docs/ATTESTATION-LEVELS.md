# Attestaation tasot ja todentajan vastaukset

**Kirjattu:** 2026-11-19. Sitoo todentajan (Trust Server) toteutuksen.
Muutokset tähän tiedostoon tehdään PR:nä ennen koodimuutosta, jota ne koskevat.

## Ehdoton sääntö

**Puuttuvaa, lukukelvotonta tai tukematonta mittaustietoa ei koskaan tulkita
onnistuneeksi attestaatioksi.** Todentaja ei palauta yhtä OK-statusta. Se
palauttaa jokaisesta väitteestä oman tuloksensa.

## Väitteet

| Tunnus | Väite | Mitä se tarkoittaa | Mitä se EI tarkoita |
|---|---|---|---|
| **A** | Identiteetti | Vastauksen allekirjoitti avain, joka on laitteistossa (TPM, TEE tai StrongBox) eikä ole siirrettävissä, ja sama avain otettiin käyttöön tälle laitteelle rekisteröinnissä. | Ei kerro, mitä ohjelmistoa laite ajaa. |
| **B** | Käynnistysketju | Laitteistoon ankkuroitu mittaus- tai tarkistusketju todistaa käynnistyksen tilan (esim. Android verified boot ja lukittu bootloader, UEFI-PCR:t 0–7). | Ei kerro ajonaikaisesta tilasta käynnistyksen jälkeen. Ei kerro sovelluskerroksesta. Ei suojaa haavoittuvuuksilta, joita päivitystaso ei korjaa. |
| **P** | Päivitystaso | Laitteen raportoima tietoturvapäivitystaso. Laitteistoon ankkuroitu vain, jos se tulee samasta attestaatiorakenteesta kuin B. | Ei kerro, onko tasoa uudempia korjauksia olemassa. |
| **Q** | Kvanttiturvallinen allekirjoitus | Vastauksessa on ML-DSA-65-allekirjoitus, ja todentaja tietää, onko avain laitteistossa vai ohjelmistossa. | Ohjelmistossa oleva ML-DSA-avain ei ole A-tason identiteetti. Laitteiston klassinen juuri (ECDSA, RSA) ei ole kvanttiturvallinen. |

C ei ole oma väite. "C" tarkoittaa, että A ja B ovat molemmat `VERIFIED` samassa vastauksessa.

## Tulokset per väite

| Tulos | Merkitys |
|---|---|
| `VERIFIED` | Väite todennettu laitteistoon ankkuroiduista todisteista ja rekisteröintiin verrattuna. |
| `FAILED` | Todisteet ovat ristiriidassa rekisteröinnin tai käytännön kanssa (väärä avain, muuttunut PCR, avattu bootloader, allekirjoitus ei täsmää). |
| `PARTIAL` | Osa väitteen todisteista on todennettu, osa ei. Vastaus nimeää todennetut ja todentamattomat osat. |
| `UNSUPPORTED` | Laitteella ei ole rakenteellisesti mekanismia, jolla väitteen voisi todentaa (esim. Pi 5:n käynnistysketju). |
| `UNKNOWN` | Todisteita ei saatu tai niitä ei voitu tulkita (puuttuva kenttä, jäsennysvirhe, tuntematon formaatti, verkkovirhe). |

Säännöt:
- `PARTIAL`, `UNSUPPORTED` ja `UNKNOWN` eivät ole koskaan `VERIFIED`.
- Jos jokin todisteen osa puuttuu, tulos on `UNKNOWN` tai `PARTIAL`, ei oletusarvo.
- Ensimmäinen näkeminen (rekisteröimätön laite) ei ole `VERIFIED` millekään
  väitteelle. Rekisteröinti on erillinen, käsin hyväksytty toimenpide.
- Vastaus sisältää jokaisen väitteen tuloksen, perustelun ja todentajan
  käytännön version (`policy_id`).

## Hyväksymiskäytäntö

Käytäntö on erillinen tiedosto todentajalla, laitekohtainen ja versioitu. Se
päättää, mikä yhdistelmä riittää mihinkin käyttöön. Esimerkki:

- **S24, tuotanto:** A = `VERIFIED`, B = `VERIFIED`, P ≥ 90 päivää vanha tai
  uudempi, Q = `VERIFIED` (ML-DSA-avaimen säilytystaso kirjattuna).
- **S21, testi:** A ja B `VERIFIED`, P hyväksytään tasolla 2026-01 sillä
  tiedolla, että tukea ei ole. Ei tuotantokäyttöön.
- **Pi 5:** A = `VERIFIED`; B = `UNSUPPORTED` hyväksytään tietoisesti.

Käytäntö ei voi muuttaa väitteen tulosta. Se voi vain päättää, riittääkö tulos.

## Negatiivikontrollit (CI)

Jokaiselle säännölle testi, jonka täytyy epäonnistua: puuttuva quote, väärä
nonce, muokattu PCR, puuttuva kenttä, rekisteröimätön laite, väärä
allekirjoitus, avattu bootloader (Android-todistesarjasta). Todentaja ei ole
valmis ennen kuin jokainen näistä antaa `FAILED` tai `UNKNOWN`, ei `VERIFIED`.
