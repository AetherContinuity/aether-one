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

## Tarkistettavuus

Nama saannot ovat mekaanisia: statusdokumentin voi grepata
superlatiiveista ("taydellisesti", "erittain", "merkittava",
emojit) samalla tavalla kuin sivukanavamainintoja voi gropata
muualta. Tama TARKOITTAA etta noudattamista VOI JA PITAA tarkistaa
mekaanisesti, ei vain luottaa hyvaan tahtoon.
