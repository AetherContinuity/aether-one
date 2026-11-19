# Aether One — ohje agenttisessioille (AGENTS.md = CLAUDE.md)

Lue tämä ennen kuin muutat tai ajat mitään. Sama sisältö on tiedostossa
`AGENTS.md` muille agenteille (esim. Kimi Code). Kieli: suomi, kuiva ja suora.

## Aloita näistä, tässä järjestyksessä

1. `BASELINE-v1.0.md`: jäädytetty tilannekuva 2026-11-16. Jokainen väite
   viittaa todisteeseen (CI-job tai tiedosto).
2. `KORJAUSLISTA.md`: avoimet kohdat ja niiden tila. Elävä dokumentti.
3. `README.md`: tila osittain ja todennustaso (CI / kerta-ajo).

Muut markdown-tiedostot ovat pääosin historiallisia tilannekuvia (otsake
"Historiallinen tilannekuva"). Ne eivät kuvaa nykytilaa. Älä suunnittele
työtä niiden perusteella tarkistamatta asiaa yllä olevista.

## Suunta (päätetty 2026-11-16)

- **RTL on jäädytetty `BASELINE-v1.0.md`:n tilaan.** Nykyinen ML-KEM-
  orkestrointi ei mahdu ECP5:lle (KORJAUSLISTA B4). RTL:ää ylläpidetään
  (testit toistettaviksi), mutta sitä ei laajenneta.
- **Työn alla: ohjelmistopohjainen laitteiden attestaatio**, Linux ja Android
  rinnakkain, käyttäjän omat laitteet. Suunnitelma on kesken; se kirjataan
  repoon ennen toteutusta.

Jo tehty, älä tee uudelleen: ML-KEM K-parametrisointi ja oletus K=3
(ML-KEM-768), täysi NIST ACVP K=2 ja K=3, Decaps-sivukanavaotos (B8),
B4:n rekisteribudjetti.

## Pysyvät säännöt

- **Muutokset PR:nä**, ei suoraan mainiin. Käyttäjä yhdistää.
- **Mittaus ennakkorekisteröidään.** Hypoteesit ja hylkäyssäännöt
  commitoidaan ennen mittauskoodia ja tuloksia (malli:
  `hardware/pqc-rtl/sivukanava/B8-ENNAKKO.md`, `hardware/pqc-rtl/b4/B4-ENNAKKO.md`).
  Poikkeama kirjataan erilliseen `*-POIKKEAMA-N.md`-tiedostoon.
- **Mittarin täytyy pystyä epäonnistumaan.** Jokaiselle PASS-väitteelle
  negatiivikontrolli (turmeltu vektori, vajaa tiedosto, vuotava muunnelma).
- **Ulkoinen mittapuu ensin.** NIST ACVP -vektorit (`usnistgov/ACVP-Server`
  975de31, sha256 kiinnitetty skripteissä) ovat riippumaton referenssi.
  LLM-katselmointi (`katselmoinnit/`) vain siellä, missä ulkoista
  mittapuuta ei ole.
- **Raportointikuri:** `hardware/pqc-rtl/REPORTING-DISCIPLINE.md`; CI ajaa
  `check_reporting_discipline.sh`:n. README:n tilapäiväys ei saa olla
  KORJAUSLISTA:n päiväystä vanhempi.

## Simulaatio

- Icarus Verilog (`iverilog -g2012`) ja Verilator (lint). Golden-mallit ja
  vektorigeneraattorit: Python 3, vain vakiokirjasto.
- **Lisää `hardware/pqc-rtl/tools/vvp-tarkka` PATHin alkuun.** Icarus jatkaa
  ajoa virheellisellä tiedostokahvalla; odotusarvot jäävät X:iksi ja
  X === X läpäisee vertailun (KORJAUSLISTA A13). Kääre tekee tiedostovirheestä
  FAILin.
- Vektoritiedostot `hardware/pqc-rtl/vectors/` ovat osin generoituja ja
  gitignoroituja. Testi voi riippua toisen skriptin generoimasta tiedostosta
  (A11, A14): aja puhtaasta kloonista ennen kuin päättelet mitään.
- CI: `.github/workflows/verify.yml`. Raskaat ML-DSA-testit:
  `dilithium-heavy-integration.yml` (käsin).

## Tunnetut ansat

- Yosys 0.33 kaatuu (`Assert modules_.count`), kun `hierarchy -chparam K`
  yhdistyy alimoduulien uudelleenkäsittelyyn. K=3 on oletus; käytä
  `read_verilog -sv -defer` ilman `-chparam`ia (`hardware/pqc-rtl/b4/`).
- Icarus: `?:`-lausekkeessa eripituiset merkkijonot täydennetään NUL-tavuilla;
  `$fopen` epäonnistuu. Käytä if/else-rakennetta.
- Clauden pilvisession git-proxy estää tagien ja git-objektien kirjoittamisen;
  baseline on tiedosto, ei tagi.
