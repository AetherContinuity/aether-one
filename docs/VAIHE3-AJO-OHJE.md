# Vaihe 3b: laiteajon ohje (S21 ensin, sitten S24)

Kriteerit ja hypoteesit: `docs/VAIHE3-ENNAKKO.md`. Tulokset kirjataan
`docs/VAIHE3-TULOS.md`:hen; laitteen ketjuja ei commitoida.

## Pi 2 (todentaja)

```bash
cd ~/pi2_trust_server
git pull                       # vähintään vaiheen 3 PR
./install.sh                   # asentaa myös cryptographyn; vaatii tpm2-toolsin
./start.sh                     # portti 5000
```

Todentaja hakee Googlen revokaatiolistan itse (`android.googleapis.com`);
Pi 2 tarvitsee internet-yhteyden. Ilman listaa A on enintään `PARTIAL`.

## Puhelin: asennus

1. Lataa APK GitHubista: Actions → viimeisin `verify`-ajo haarasta → artefakti
   `aether-attest-apk`. Tarkista sha256 ajon lokista (vaihe "APK:n sha256").
2. Samsung: Asetukset → Tietoturva ja yksityisyys → Auto Blocker → pois.
3. Asenna APK (tiedostot-sovellus → salli asennus tälle lähteelle kerran).
4. Auto Blocker takaisin päälle heti asennuksen jälkeen. Peru myös
   "tuntemattomien sovellusten asennus" -lupa tiedostot-sovellukselta.
5. Älä avaa bootloaderia, älä roottaa.

## Rekisteröinti

1. Pi 2: `python -m core.trustcore.admin android-nonce` → 64 heksamerkkiä
   (voimassa 15 min).
2. Sovellus: todentajan osoite (`http://<pi2-ip>:5000`), nonce, **Rekisteröi**.
   Kirjaa näytön diagnostiikka (tila, StrongBox/TEE, huomiot).
3. **Jaa rekisteröintitiedot** → siirrä teksti Pi 2:lle tiedostoksi
   `laite.json` (esim. sähköposti itselle tai leikepöytä + ssh).
4. Pi 2: `python -m core.trustcore.admin enroll-android laite.json`.
   Hylkäys tulostaa syyn; kirjaa se sellaisenaan.

## Mittaus

1. **Attestoi** kolme kertaa. Kirjaa jokaisesta A, B, P, Q ja perustelut.
2. **Diagnostiikka**: kirjaa koko tuloste (ketjun pituus, liitettiinkö K:n
   ketju, ominaisuusliput).
3. Negatiivikontrollit:
   - **Kontrolli: lähetä edellinen paketti uudelleen** → odotus kaikki `UNKNOWN`.
   - **Kontrolli: attestoi turmellulla ketjulla** → A ei `VERIFIED`.
   - device_id-ohitus: kirjoita toisen puhelimen device_id kenttään ja
     **Attestoi** → odotus A `FAILED`. (Vasta kun molemmat on rekisteröity.)
   - Ennen rekisteröintiä Pi 2:lla: **Attestoi** → kaikki `UNKNOWN`.
4. Pi 2: kirjaa `devices.json`-tietueen kentät `mode`, `security_level`,
   `enroll_patch_levels` (ei avaimia).

Liitä tulokset keskusteluun tai repoon tekstinä. Älä liitä APK:n
allekirjoitusavainta tai salasanoja.
