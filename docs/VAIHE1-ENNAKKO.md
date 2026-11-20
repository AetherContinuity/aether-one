# Vaihe 1: todentajan ydin — hyväksymiskriteerit (ennakkoon)

**Kirjattu:** 2026-11-20, ennen yhtään vaiheen 1 koodimuutosta.
Sitova lähde: `docs/ATTESTATION-LEVELS.md`. Korjaa: KORJAUSLISTA A16.
Poikkeamat näistä kriteereistä tuloksen jälkeen: `VAIHE1-POIKKEAMA-N.md`.

## Rajaus

Linux-attestoija (Pi 5 / CI), TPM swtpm:llä. Android ja Pi 2:n asennus eivät
kuulu tähän vaiheeseen. PCR-lähtötila (B Linuxilla) ei kuulu tähän vaiheeseen,
koska yhdelläkään nykyisellä Linux-laitteella ei ole mitattua käynnistystä
(`ATTESTATION-ARCHITECTURE.md`): B on näille `UNSUPPORTED`.

## Lisähavainto ennen kriteereitä

`pi5_edge_node/setup_swtpm.sh` luo AK:n komennolla `tpm2_create -G rsa` ilman
`restricted`-attribuuttia. Rajoittamaton avain voi allekirjoittaa mitä tahansa
dataa (`tpm2_sign`), myös itse rakennetun "quoten". Sellaisen avaimen quote
ei todista TPM:n tilasta mitään. Korjataan tässä vaiheessa (K2).

## Hyväksymiskriteerit

Vaihe 1 on valmis, kun kaikki pätevät CI:ssä.

**K1 Väitekohtainen vastaus.** `/verify` palauttaa väitteet A, B, P ja Q
erikseen, kukin tuloksella `VERIFIED | FAILED | PARTIAL | UNSUPPORTED | UNKNOWN`
ja perustelulla. Ylätason `status`-kenttää (PASS/FAIL) ei ole.

**K2 AK on rajoitettu allekirjoitusavain.** Provisiointi luo AK:n
attribuuteilla `fixedtpm|fixedparent|sensitivedataorigin|userwithauth|restricted|sign`.
Rekisteröintityökalu kieltäytyy AK:sta, jolta puuttuu `restricted`, `sign` tai
`fixedtpm`.

**K3 TPM-quote tarkistetaan.** A perustuu siihen, että quoten allekirjoitus
täsmää rekisteröityyn AK:hon, quoten `extraData` on tämän pyynnön nonce ja
PCR-arvojen digest täsmää quoteen (`tpm2_checkquote`).

**K4 Rekisteröinti on käsin.** Ensimmäinen näkeminen ei rekisteröi.
Rekisteröinti tehdään todentajalla ylläpitotyökalulla (AK:n julkinen avain,
ML-DSA-65:n julkinen avain, alusta, TPM-tyyppi). Laitteen itse allekirjoittama
`/enroll` poistetaan.

**K5 swtpm ei ole laitteistoa.** Laite, jonka TPM-tyypiksi on rekisteröity
`swtpm`, saa A:lle enintään `PARTIAL` (perustelu: AK ohjelmisto-TPM:ssä).

**K6 B ja P.** Alustalle, jolla ei ole mitattua käynnistystä (rpi5, swtpm-CI),
B = `UNSUPPORTED`. Linuxilla P = `UNSUPPORTED`.

**K7 Q.** ML-DSA-65-allekirjoitus kattaa laitteen tunnisteen, noncen ja
quoten tiivisteen. Q:n perustelu nimeää avaimen säilytystason (Linuxilla:
ohjelmisto).

**K8 Negatiivikontrollit.** Jokainen alla oleva tapaus ajetaan CI:ssä, ja
jokaisen on annettava mainittu tulos. Yksikään ei saa antaa `VERIFIED`
mainitulle väitteelle:

| Tapaus | Odotettu tulos |
|---|---|
| quote puuttuu | A `UNKNOWN` |
| quoten allekirjoitus turmeltu | A `FAILED` |
| quote allekirjoitettu toisella AK:lla | A `FAILED` |
| quoten nonce eri kuin pyynnön | A `FAILED` |
| PCR-arvo muutettu quoten jälkeen | A `FAILED` |
| pyynnön nonce tuntematon tai jo käytetty | kaikki `UNKNOWN` |
| rekisteröimätön laite | kaikki `UNKNOWN` |
| ML-DSA-allekirjoitus turmeltu | Q `FAILED` |
| ML-DSA-allekirjoitus puuttuu | Q `UNKNOWN` |
| rajoittamaton AK rekisteröinnissä | rekisteröinti kieltäytyy |

Lisäksi positiivinen tapaus: rekisteröity swtpm-laite, ehjä todiste →
A `PARTIAL`, B `UNSUPPORTED`, P `UNSUPPORTED`, Q `VERIFIED`.

**K9 Yksi lähde.** `pi2_trust_server/core/trustcore` ja
`pi5_edge_node/core/trustcore` ovat nyt identtiset kopiot. CI tarkistaa,
että ne pysyvät identtisinä.

## Ei tässä vaiheessa

EK-varmenneketju ja credential activation (AK:n TPM-alkuperä todistetaan
rekisteröinnissä omistajan fyysisellä läsnäololla), PCR-lähtötila,
hash-ketjutettu päätösloki, Android.
