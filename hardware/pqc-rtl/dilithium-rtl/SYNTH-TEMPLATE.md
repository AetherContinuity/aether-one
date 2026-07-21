# SYNTH-xxx -tehtavien vakiorakenne

Tama dokumentti maarittaa YHTEISEN mallin kaikille suorituskyky-/
resurssioptimointitehtaville (`SYNTH-xxx-*.md`), erillisena
toiminnallisen oikeellisuuden todentamisesta (ks. `TESTING.md`,
`REPRESENTATION_CONTRACT.md`). Tarkoitus: sama kurinalaisuus
optimointityolle kuin mika on jo rakennettu toiminnalliselle
verifioinnille - "engineering notebook" -periaate.

## Miksi tama on oma dokumenttinsa erillaan itse tehtavista

Jotta jokainen `SYNTH-xxx-*.md` noudattaa SAMAA rakennetta
riippumatta siita, kuka sen kirjoittaa tai milloin - samalla tavalla
kuin `TESTING.md` maarittaa Unit/Component/Integration-taksonomian
KERRAN, ja jokainen yksittainen testi vain noudattaa sita.

## Vakiorakenne (JOKAISEN SYNTH-xxx-tehtavan tulee sisaltaa nama
   kohdat, tassa jarjestyksessa)

| Kohta | Sisalto |
|---|---|
| **Tavoite** | Mita TASMALLEEN optimoidaan (yksi moduuli/rakenne, EI koko putki kerralla - ks. SYNTH-001:n oma perustelu kapean kohteen valinnasta) |
| **Lahtotilanne** | MITATUT (EI arvioidut) nykyarvot: `ltp`-tasot, solumaara, FF-maara, sykliaika jos tunnettu |
| **Muutos** | Tarkka arkkitehtuurimuutos (esim. "jaetaan N rekisteroituun vaiheeseen kohdasta X") |
| **Mittarit** | Mika TASMALLEEN mitataan JOKAISELLE variantille: `ltp`-logiikkatasot, solu-/FF-maara (Yosys `synth`+`stat`), syklimaara (simulointi), Fmax (VASTA kun P&R-resursseja on kaytettavissa - EI pakollinen valikriteeri) |
| **Hyvaksymiskriteeri** | Mita PARANNUKSEN TAYTYY saavuttaa jotta muutos hyvaksytaan (esim. "ltp <60 tasoa JA kaikki olemassa olevat Unit/Component-tason NTT-testit pysyvat vihreina JA syklimaaran kasvu <10%") |

## Prosessisaanto: mittaus ENNEN ja JALKEEN, ei vain JALKEEN

Jokaisen SYNTH-xxx-tehtavan "Lahtotilanne"-kohta TAYTYY tayttaa
EROLLAAN toimenpiteesta - eli MITTAA nykytila ENSIN (kuten SYNTH-001
teki: 107 tasoa, 6517 solua, 0 FF ennen mitaan muutosta), VASTA SEN
JALKEEN tee muutos ja mittaa uudestaan. Tama estaa "olettamalla
parantunutta" -virhepaatelmaa - sama periaate kuin
`REPRESENTATION_CONTRACT.md`:n oma vaatimus ("tarkista LAHTEEN
TODELLINEN esitysmuoto, ei oletettu").

## Suhtautuminen olemassa olevaan testi-infrastruktuuriin

Optimointitehtavan HYVAKSYMISKRITEERIIN TAYTYY AINA sisaltaa: "kaikki
asiaankuuluvat Unit-/Component-tason testit (`TESTING.md`) pysyvat
vihreina muutoksen jalkeen" - suorituskykyoptimointi EI SAA rikkoa
toiminnallista oikeellisuutta, ja OLEMASSA OLEVA nopea testi-
infrastruktuuri (EI uusi raskas integraatiotesti) riittaa taman
todentamiseen useimmille RTL-tason muutoksille (ks. SYNTH-001:n
oma perustelu: Barrett-mulmod:in Unit-tason testi + NTT:n oman
Component-tason testin uudelleenajo riittaa).

## Nimeamiskaytanto

`SYNTH-<juokseva numero>-<lyhyt-kuvaava-nimi>.md`, esim.
`SYNTH-001-barrett-pipeline.md`. Jokainen uusi tehtava saa seuraavan
juoksevan numeron riippumatta siita onko edellinen viela avoinna
vai suljettu.
