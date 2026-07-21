# SYNTH-003A: Barrett 3-stage integration into NTT core

**Status:** Open
**Created:** 2026-07-21
**Related:** `SYNTH-002-barrett-3stage.md`, `pqc_dilithium_barrett_mulmod_pipe3.sv`,
`pqc_dilithium_ntt_core.sv`, `pqc_dilithium_ntt_inverse_core.sv`

**Kayttajan oma rajaus:** tama on PUHTAASTI integraatiotehtava - EI
optimointitehtava. Normalisointilogiikan oma optimointi (Vaihe 3:n
oma raskaus, 41 tasoa) on ERIKSEEN `SYNTH-003B-normalization-
optimization.md`:ssa. Naita EI sekoiteta samaan tehtavaan.

## Vakiorakenne (ks. SYNTH-TEMPLATE.md)

| Kohta | Sisalto |
|---|---|
| **Tavoite** | Ottaa `pqc_dilithium_barrett_mulmod_pipe3.sv` (SYNTH-002:ssa toteutettu, testattu, mitattu 3-vaiheinen pipeline) KAYTTOON `pqc_dilithium_ntt_core.sv`:ssa JA `pqc_dilithium_ntt_inverse_core.sv`:ssa nykyisen taysin kombinatorisen `pqc_dilithium_barrett_mulmod.sv`:n SIJAAN. |
| **Lahtotilanne** (MITATTU) | NTT-ydin (forward): `ltp` koko moduulille EI viela mitattu tassa kontekstissa (aiempi 39317 solua/5979 FF ON synteesin oma solu-/FF-maara, EI ltp - ks. `SYNTHESIS_REPORT.md`). NTT-ytimen oma sykliaika/NTT-muunnos: baseline dokumentoitu `pqc_dilithium_ntt_core.sv`:n omissa aiemmissa mittauksissa (ks. DK1-status: ~3584-4095 sykli/NTT bring-up-versiolle). Barrett-mulmod:in kaytto NTT-ytimen OMASSA FSM:ssa: YKSI tila, jossa `mm_a_in`/`mm_b_in` asetetaan JA `mm_out` luetaan SAMALLA/SEURAAVALLA syklilla (kombinatorinen oletus - TARKISTETAAN tarkka rivi ENNEN muutosta). |
| **Muutos** | (1) Vaihdetaan `pqc_dilithium_barrett_mulmod`-instanssi `pqc_dilithium_barrett_mulmod_pipe3`-instanssiksi seka NTT-ytimessa etta kaanteisessa NTT-ytimessa. (2) Muokataan kummankin OMAA FSM:aa lisaamalla KOLME odotussykleaa (tai suunnitellaan pipeline-tayttoa hyodyntava rakenne, JOS butterfly-silmukka sallii sen - PAATETAAN toteutusvaiheessa kumpi lahestymistapa on yksinkertaisempi TAMAN koodikannan nykyiselle FSM-rakenteelle). |
| **Mittarit** | (1) Uusi kokonaissyklimaara YHDELLE taydelle 256-kertoimen NTT-muunnokselle (seka forward etta inverse), verrattuna baseline-arvoon. (2) KAIKKI olemassa olevat Unit-/Component-tason NTT-testit (`TESTING.md`-taksonomia) - TAYTYY pysya vihreina TAYSIN MUUTTUMATTOMINA (sama testivektorit, sama odotettu tulos - VAIN sykliaika saa muuttua, EI lopputulos). (3) Solu-/FF-maara koko NTT-ytimelle (odotettu: FF kasvaa `pipe3`:n oman 139 FF:n verran KERTAA Barrett-instanssien maara jos EI jaeta yhta instanssia useaan kutsuun - TARKISTA tama NTT-ytimen omasta rakenteesta ENNEN arviointia). |
| **Hyvaksymiskriteeri** | (a) KAIKKI olemassa olevat NTT:n Unit-/Component-tason testit PASS TAYSIN MUUTTUMATTOMINA (sama golden-data kuin ennen - tama on PUHDAS ajoitusmuutos, EI algoritmimuutos, joten TULOKSEN TAYTYY olla bittitasan sama, VAIN nopeammin/hitaammin saavutettu). (b) Sykliverkutus per NTT-muunnos dokumentoitu ja perusteltu (odotetaan pientä kasvua Barrett-kutsujen omasta lisalatenssista, MUTTA taman TAYTYY olla kohtuullinen suhteessa mahdolliseen Fmax-hyotyyn). (c) Verify/Sign/KeyGen:n omat Integration-tason regressiot (jotka KAIKKI kayttavat NTT-ydinta valillisesti) PASSAAVAT edelleen - TAMA VAATII vahintaan yhden kevyen Integration-tason uudelleenajon (ei valttamatta koko raskasta workflow'ta, mutta EDES yhta nopeaa Sign/Verify-referenssitestia). |

## Tausta

SYNTH-002 osoitti etta 3-vaiheinen Barrett-pipeline ON toiminnallisesti
oikea JA tasapainoinen (`ltp` 39/33/41, kaikki alle 60 tason
tavoitteen). TAMA TEHTAVA vie taman KAYTANTOON - eli oikeasti KAYTTOON
NTT-ytimessa, joka on ML-DSA-65:n eniten kaytetty rakennuspalikka
(kaikki kolme paaoperaatiota - KeyGen, Sign, Verify - kayttavat sita
laajasti).

## Miksi tama on ERI tehtava kuin SYNTH-003B

Kayttajan oma perustelu: integraatiotyo (FSM-muutokset, ajoitus-
kasittely) ja suorituskykyoptimointi (normalisointilogiikan oma
sisainen rakenne) EIVAT SAA sekoittua samaan tehtavaan - jos
molemmat tehtaisiin yhdessa, olisi vaikea sanoa JALKIKATEEN kumpi
muutos (integraatio vai normalisoinnin optimointi) aiheutti minka
tahansa havaitun vaikutuksen (positiivisen tai negatiivisen).

## Rajaukset (EI kuulu tahan tehtavaan)

- Normalisointilogiikan (Vaihe 3, 41 tasoa) oma sisainen optimointi -
  ks. `SYNTH-003B-normalization-optimization.md`.
- Fmax-mittaus (edelleen jumissa P&R-resurssirajoitteen takia tassa
  ymparistossa, sama avoin kysymys kuin SYNTH-001/002:ssa).
- Paatoksenteko SIITA, otetaanko 2- vai 3-vaiheinen variantti
  kayttoon - TAMA TEHTAVA OLETTAA etta 3-vaiheinen on valittu
  (SYNTH-002:n oman johtopaatoksen mukaisesti), mutta jos taman
  paatoksen halutaan viela vahvistaa erikseen ENNEN integraatiota,
  se on oma, aiempi keskustelu, ei tamän tehtavan oma sisalto.
