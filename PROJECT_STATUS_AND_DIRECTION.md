# PROJECT_STATUS_AND_DIRECTION.md

## Tarkoitus ja yleisö (lisätty 2026-07-27, täsmentää — ei korvaa — 19.7. päätöstä)

Tämä on **tutkimusprototyyppi**, ajettuna Raspberry Pi 2 + Pi 5 -asetelmalla,
ei työnhakuportfoliokappale. Molemmat ovat totta yhtä aikaa: DCEIN/TAU-
arkkitehtuurivisio (ks. alla) on aito ja ohjaa yhä suuntaa, mutta tavoite
tässä vaiheessa on arkkitehtuurin ja ACVP-ankkuroidun oikeellisuuden
tutkiminen — ei suorituskyvyllä kilpaileminen, eikä työnhakua varten
rakennettu näyteikkuna. Repo on avoin (ks. LICENSE, lisätty 2026-07-27)
koska ajatuksena on että muutkin voisivat hyötyä tästä, ei koska sitä
markkinoidaan mihinkään suuntaan.

**Tästä seuraa suoraan tulkinta ainoalle repossa esiintyvälle
suorituskykyluvulle (Fmax 30.4 MHz, ML-KEM NTT, ECP5) ja siitä
johdetulle ~30x hitaammalle nopeudelle Pi 5:n CPU:hun verrattuna
(FIPS203_COVERAGE.md, NIST_ACVP_STATUS.md):** tämä on **dokumentoitu
rajaus**, ei pysäyttävä puute. Tavoite ei koskaan ollut voittaa CPU:ta
lapiläpimenossa — tavoite on synteesikelpoinen, todennettu PQC-ydin
joka voi toimia TAU:n (Trust Anchor Unit) kaltaisena luottamusankkurina
arkkitehtuurissa jossa nopeus ei ole ensisijainen kriteeri. Jos suunta
joskus muuttuu kohti oikeaa laitepolkua/tuotantoa, tämä luku on
ensimmäinen asia joka pitää arvioida uudestaan, ennen mitään muuta.

**Ainoa tunnistettu, yhä ratkaisematon avoin kysymys:** K=2 (ML-KEM-512,
turvakategoria 1) rinnalla suunniteltu M5-DILITHIUM-001 (ML-DSA-65,
turvakategoria 3) muodostaisi turvatasoiltaan epäsuhtaisen parin, jos
molemmat toteutuisivat sellaisenaan samaan järjestelmään. Tätä ei ole
vielä ratkaistu eikä sen tarvitse ratkaista NYT — mutta hinta kasvaa
jokaisen uuden K=2-oletukseen sidotun testipenkin myötä, joten se
kannattaa pitää mielessä ennen M5-DILITHIUM-001:n laajempaa työtä.

---

**Paivamaara:** 2026-07-19
**Tarkoitus:** tallettaa projektin nykytila ja sovittu jatkosuunta ennen
seuraavan tyovaiheen (M4-TAU-001) aloitusta.

## Missa ollaan nyt

### hardware/pqc-rtl/ (ML-KEM/Kyber RTL) - taydellisesti todistettu

| Vaihe | Tila |
|---|---|
| M1-M2 | NTT256, konfliktiton 4-pankkinen muisti, SAT-todistettu | ✅ |
| M3 RC1 | Koko K-PKE + ML-KEM.KeyGen/Encaps/Decaps, Keccak/SHA-3-perhe | ✅ |
| M4-FPGA-001..004 | BRAM-inferointi (DP16KD=4) tutkimusprototyypista tuotantoytimeen | ✅ |
| M4-FPGA-005..008 | ECP5 P&R, ajoitusoptimointi (Fmax 21.2->30.4 MHz, +14.5%) | ✅ |
| M4-SoC-001 | Wishbone-vaylakaare, synteesitodennettu | ✅ |

Kaikki askeleet taaksepainyhteensopivia (oletusparametrit muuttamattomia),
golden-mallilla todennettuja, ja CI-vahvistettuja.

### hardware/pqc-rtl/rvv-dilithium/ (ML-DSA-65/Dilithium ohjelmisto)

Taydellinen, bittitarkasti todennettu ohjelmistoreferenssi (C+RVV,
QEMU) - avaingenerointi + allekirjoitus + verifiointi
pq-crystals/dilithium-referenssia vasten. EI VIELA synteesikelpoista
RTL:aa.

## Yhteys DCEIN/Continuity Computing -arkkitehtuuriin

Tama tyo on paatetty asemoida palvelemaan Aether Continuity Instituten
TN-002 (DCEIN) ja WP-006 (Continuity Computing) -arkkitehtuuria:

- https://aethercontinuity.org/supplements/tn-002-dcein.html
- https://aethercontinuity.org/papers/wp-006-continuity-computing.html

**Keskeinen loydos/korjaus (2026-07-19):** aiempi oletus etta "tama
ML-KEM-tyo ei palvele Trust Serverin tuotantotarvetta (joka kayttaa
Dilithiumia)" oli LIIAN SUORAVIIVAINEN. TN-002:n oma "VERA Agent PQC
Integration" -kohta maarittaa eksplisiittisesti: **"Kyber for key
exchange, Dilithium for signatures"** - molemmat algoritmit ovat osa
samaa, tarkoituksellista PQC-pinoa. Tama rtl/-tyo on siis Kyber-
puolisko, EI kilpaileva tai tarpeeton toteutus.

**TN-002:n "TrustCore NX Architecture" -kuvaus** ("secure neural
coprocessor... combines on-die cryptographic acceleration with AI
inference... allows the TAU to validate ECU decisions using
dedicated cryptographic hardware") kuvaa tasmalleen sen tyyppista
kryptografista kiihdytinta jota olemme rakentaneet - synteesikelpoinen,
BRAM-integroitu, vaylaan liitetty PQC-ydin.

## Sovittu jatkosuunta (kayttajan paatos 2026-07-19)

Jarjestys: **M4-TAU-001 ensin, sitten M5-DILITHIUM-001.**

**Perustelu:** TAU-valmius (attestaatioprotokolla, watchdog, audit-
lokitus) on huomattavasti pienempi, nopeampi askel joka rakentuu
suoraan olemassa olevan Wishbone-kaareen paalle. Se MYOS luo
arkkitehtonisen kuvion (attestaatioprotokolla, paatoksen validointi,
audit-lokin rajapinta) jota Dilithium-tyo tarvitsisi TASMALLEEN
samanlaisena myohemmin - tekemalla taman ensin, sama TAU-kaare
palvelee molempia algoritmeja ilman kaksinkertaista tyota.

### M4-TAU-001 (GitHub Issue #16) - SEURAAVA TYOVAIHE

Tavoite: muokata ML-KEM-ydin + Wishbone-kaare TAU-valmiiksi (Trust
Anchor Unit), TN-002-arkkitehtuurin mukaisesti:
1. Watchdog/heartbeat-logiikka ECU<->TAU-viestintaa varten
2. Attestaatioprotokolla: ECU allekirjoittaa paatoksen -> TAU
   validoi -> TAU lokittaa hash
3. D4-yhteensopiva audit-loki (paikallinen, muuttumaton, deferred
   reconciliation -kykyinen)
4. Integraatio olemassa olevaan Wishbone-vaylakaareen

Metodologia: sama kurinalaisuus kuin M4-FPGA-sarjassa - tutkimus-
prototyyppi ensin, golden trace -vertailu, vasta sitten harkittu
tuotantointegraatio.

### M5-DILITHIUM-001 (GitHub Issue #17) - SEURAAVAKSI SEURAAVA

Toistaa M1-M4:ssa todistetun metodologian ML-DSA-65:lle:
konfliktiton pankitus, BRAM-arbitrointi, pipelinointi, vaylaintegraatio
(ja TAU-kaare kun M4-TAU-001 valmis). Laajuudeltaan verrattavissa
koko M1-M4-sarjaan - oma, huolellinen tyopakettinsa.

## GitHub Issues -tila (paivitetty 2026-07-19)

Suljettu tallä kertaa (ratkaistu taman istunnon tyolla):
- #2 (synth_ecp5-muistiongelma) - ratkaistu M4-FPGA-002/003/004:ssa
- #9 (Keccak/SHA-3-perhe) - ratkaistu, kaikki alaosiot valmiit
- #15 (SampleNTT/SamplePolyCBD-integraatio) - ratkaistu, koko K-PKE/ML-KEM valmis

Luotu:
- #16 M4-TAU-001 (attestaatioprotokolla) - SEURAAVA
- #17 M5-DILITHIUM-001 (Dilithium RTL) - SEURAAVAKSI SEURAAVA
