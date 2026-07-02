# Methodology

## Mekanismi (todennettu koodista, ei kuvailtu ulkoa)

`lr_open.py` laskee kolme komponenttia (R, S, E) painotettuna keskiarvona
kuudesta syöttöpisteestä (RSM, RRM, TSM, RAP, IRS, LRM), joista jokainen
saa käsin annetun arvon asteikolla [-3, +3]. Painot on määritelty
`lr_open_core.json`:ssa `affects_components`-kentässä.

R = Σ(paino_i × pisteytys_i) / Σ|paino_i|, komponenteille joihin funktio i vaikuttaa.
Sama S:lle ja E:lle. Tulos clampataan takaisin [-3, +3]-välille.

Status (Critical/Fragile/Tense/Resilient) määräytyy `min(R,S,E)`:n perusteella,
kynnyksillä -2/-1/+1.

## Mitä EI ole kalibroitu

Painot (esim. RSM: R=0.7, S=0.1, E=0.2) ovat käsin asetettuja. Ei ole
olemassa dokumenttia, datasettia tai regressiota joka perustelisi miksi
RSM vaikuttaa R:ään painolla 0.7 eikä 0.6 tai 0.8. Tätä on etsitty
useasta lähteestä (paketit, aiemmat sessiot, muistiinpanot) — ei löytynyt.
Jos perustelu on olemassa jossain toisen mallin session-historiassa, sitä
ei ole tuotu tähän dokumenttiin, koska sitä ei ole voitu vahvistaa.

Sama koskee `kri_index.weights`-kenttää (R=0.4, S=0.3, E=0.3): tämä on
konfiguraatiossa määritelty mutta `LRFramework.evaluate()` ei koskaan
laske tätä painotettua yhdistelmää — koodi tuottaa `KRI_X`:n kolmen
erillisen komponentin merkkijonona, ei yhtenä lukuna. Dokumentoitu
ominaisuus ja toteutus eroavat toisistaan.

## Mitä pitäisi olla ennen kuin painoja kutsutaan "kalibroiduiksi"

1. Historiallinen tapaustutkimus jossa R/S/E-syötteet on johdettu
   riippumattomasta datasta (ei arvioitu käsin) ja lopputulos (Critical/
   Fragile/jne.) verrattu siihen mitä oikeasti tapahtui.
2. Herkkyysanalyysi: kuinka paljon status muuttuu jos yksittäistä painoa
   siirretään ±0.1? Jos lopputulos ei muutu merkittävästi, painon
   tarkka arvo on merkityksetön eikä sitä kannata esittää tarkkuudella
   jota sillä ei ole.
3. Sama status-luokittelu tuotettuna eri painoasetuksilla samalle
   historialliselle datalle — jos tulokset eroavat radikaalisti, malli
   on ylikalibroitu satunnaisiin valintoihin.

Yhtään näistä kolmesta ei ole tehty. `wem_bridge/` (tämän repon toinen
kansio) on ensimmäinen askel oikeaan suuntaan yhdellä kapealla osa-alueella
(R/S energiaverkkodatasta) mutta ei kata kuutta alkuperäistä funktiota
eikä KRI_X-tason logiikkaa.

## Aiempi tila

Tämä tiedosto sisälsi aiemmin vain rivin "See main conversation draft" —
viittauksen keskusteluun jota ei ole tallennettu mihinkään tässä repossa
olevaan tiedostoon. Sisältö korvattu 2026-07-02 kuvaamaan mitä koodi
todella tekee, sen sijaan että viitattaisiin kadonneeseen lähteeseen.
