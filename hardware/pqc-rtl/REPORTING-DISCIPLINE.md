# REPORTING-DISCIPLINE.md

Kolme saantoa statusdokumenttien (`*_STATUS.md`, `NIST_ACVP_STATUS.md`,
`SYNTH-*.md` jne.) kirjoittamiselle. Lisatty 2026-07-21 kayttajan
oman kritiikin seurauksena: aiempi ML-KEM-KeyGen-ACVP-raportointi
sisalsi kaksi eri virhetta samassa dokumentissa - toinen sanamuodossa
("riippumaton vahvistus" konvergenssista), toinen painotuksessa
(first-try-PASS deterministisessa putkessa esitettiin saavutuksena).

## Saanto 1: tulos raportoidaan ilman arvottamista

"PASS, tcId=1, 8024 sykli" riittaa. Ei emojeita, ei "taydellisesti",
ei ensimmaisen yrityksen juhlintaa. First-try-PASS deterministisessa
putkessa (ei haarautuvia polkuja, jo validoitu omassa regressiossa)
ON ODOTUSARVO, ei saavutus - saannon rikkominen nayttaa siis siltaokin
JOS tulos on sinallaan oikea.

## Saanto 2: oman tyon merkitysta ei arvioida samassa dokumentissa jossa tyo raportoidaan

Lauseet tyyliin "tama on merkittavasti vahvempi todiste" EIVAT kuulu
statusdokumentteihin. Ne kuuluvat ERILLISEEN arviointiin - mieluiten
kayttajan tai eri instanssin tekemana. Sama periaate kuin ACI-corpuksen
oma CN-004 (kalibrointiasymmetria institutionaalisessa ja koneellisessa
tilivelvollisuudessa): toteuttaja on huonoin arvioimaan oman
todistuksensa painoarvoa.

## Saanto 3: konvergenssia ei kutsuta vahvistukseksi

Jos SAMA malli-instanssi SAMALLA kontekstilla (sama repo, samat
dokumentoidut opit muistissa) paatyy samaan johtopaatokseen kuin
aiempi tyo, tama kirjataan KONVERGENSSINA, EI "riippumattomana
vahvistuksena". Riippumaton vahvistus vaatisi jomman kumman: (a)
ERI mallin ilman jaettua muistia/kontekstia, tai (b) ihmisen oman
tarkistuksen. Tama koskee erityisesti tilanteita joissa uusi tyo
"vahvistaa" aiemman tyon oman menetelman - konvergenssi samasta
lahdeaineistosta EI ole itsenainen evidenssi menetelman
oikeellisuudesta, vaikka menetelma sattuisikin olemaan oikea.

## Historiallinen tila (rehellinen huomio, ei korjaustoimenpide)

Grep-tarkistus 2026-07-21 osoitti etta tama kuvio (superlatiivit,
oman tyon arvottaminen samassa dokumentissa) on LAPILEIKKAAVA lahes
kaikissa taman projektin aiemmissa status-dokumenteissa (DK1-DK6,
NIST_ACVP_STATUS, SYNTH-001, SYNTHESIS_REPORT). Naita EI kirjoiteta
retroaktiivisesti uudelleen tassa - se olisi oma, erillinen, tietoinen
paatos, ei refleksiivinen ele tehtyna heti taman saannon kirjaamisen
jalkeen (mika itsessaan olisi saannon 2 hengen vastainen: oman
korjausteon laajuuden esittely ei ole sama asia kuin korjaus).
Saanto koskee JATKOSSA kirjoitettavia dokumentteja.

## Tarkistettavuus: kieltolista + CI-grep

Kayttajan oma huomio 2026-07-21: periaatetasolle jaava saantodokumentti
on itsessaan rituaali jota se yrittaa estaa - "raportoidaan ilman
arvottamista" ei ole tarkistettavissa ellei sita operationalisoi
KIELLETYIKSI SANOIKSI. Alla on TASMALLINEN kieltolista ja CI-skripti
joka gropaa sen "elavista referensseista" (ks. maaritelma alla) -
EI historiallisista milestone-lokeista, jotka sailyvat sellaisenaan
(paivatty tapahtumakirjaus, ei voimassa oleva evidenssivaite).

**Elava referenssi** = dokumentti johon TULEVAT sessiot ankkuroituvat
lahtooletuksena (esim. `NIST_ACVP_STATUS.md`, `M3_MLKEM_ACVP_STATUS.md`,
`FIPS203_COVERAGE.md`, `README.md`:n oma tilataulukko). **Historiallinen
loki** = paivatty tapahtumakirjaus menneesta debug-loydosta tai
virstanpylvaasta (esim. `DK1_STATUS.md`...`DK6_STATUS.md`:n oma
"jatko N" -kirjaus, `README.md`:n yksityiskohtaiset narratiivikohdat) -
naita EI tarkisteta taman listan mukaan, koska niiden superlatiivit
ovat kosmeettinen vika kirjoitushetken tapahtumasta, ei nykyinen
evidenssivaite.

### Kieltolista (elaville referensseille)

```
taydellisesti / TAYDELLISESTI
erittain (+ mika tahansa positiivinen adjektiivi, esim. "erittain vahva")
merkittava / merkittavasti (paitsi kun kuvaa mitattua LUKUARVOA,
  esim. "36% lyhennys" - kuvaa TALLOIN mittaa, ei arvoa)
🎉 (tai mika tahansa emoji)
"riippumaton vahvistus" / "independent confirmation" (ELLEI dokumentoitu
  ERI mallin tai ihmisen oman tarkistuksen lahteeksi)
"ensimmaisella yrityksella" yhdistettyna arvottavaan sanaan (esim.
  "PASS ensimmaisella yrityksella!" - PELKKA "PASS, N. yritys" on OK)
```

### CI-skripti (`check_reporting_discipline.sh`, lisataan hardware/pqc-rtl/-juureen)

```bash
#!/bin/bash
# Grep-tarkistus elaville referenssidokumenteille. EI tarkista
# historiallisia lokeja (DK*_STATUS.md, README.md:n narratiivi-
# kohdat) - vain nykytilaa kuvaavat dokumentit.
set -euo pipefail
cd "$(dirname "$0")"

LIVING_DOCS="dilithium-rtl/NIST_ACVP_STATUS.md M3_MLKEM_ACVP_STATUS.md FIPS203_COVERAGE.md"
BANNED_PATTERN='TAYDELLISESTI|erittain (vahva|hyva|merkittava)|🎉|riippumaton vahvistus|independent confirmation'

FAIL=0
for doc in $LIVING_DOCS; do
  if [ -f "$doc" ]; then
    if grep -inE "$BANNED_PATTERN" "$doc"; then
      echo "FAIL: $doc sisaltaa kielletyn ilmauksen (ks. REPORTING-DISCIPLINE.md)"
      FAIL=1
    fi
  fi
done

if [ "$FAIL" -eq 0 ]; then
  echo "PASS: elavat referenssidokumentit lapaisevat raportointikuritarkistuksen"
else
  exit 1
fi
```
