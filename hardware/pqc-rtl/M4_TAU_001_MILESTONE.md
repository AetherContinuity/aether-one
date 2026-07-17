# M4-TAU-001: TAU-palvelukehys VALMIS (virstanpylväs)

**Paivamaara:** 2026-07-19
**Tila:** INFRASTRUKTUURIVAIHE PAATTYNYT - siirtyminen algoritmivaiheeseen (Decaps)

## Mika tama on

Tama merkitsee M4-TAU-001-tyopaketin (TAU:n eli Trust Anchor Unitin
palvelukehys, TN-002/DCEIN-arkkitehtuurin mukaisesti) paatepistetta.
Kaikki nelja TAU:n peruspalvelua - Wishbone-vaylaohjaus, ML-KEM.KeyGen-
orkestrointi, hash-ketjutettu audit-loki, ja watchdog-valvonta - ovat
nyt integroituja YHTEEN kokonaisuuteen, todennettuja seka onnistumis-
etta virhepolulla, ja suojattuja CI-regressiolla.

## Miksi tama on virstanpylvas eika vain yksi commit lisaa

Tama tyopaketti seurasi tarkoituksellista, nelivaiheista todennus-
ketjua joka on tutkimuksellisesti merkittava sinansa:

1. **Yksikkotestit** osoittivat etta jokainen komponentti (Wishbone-
   vayla, KeyGen-orkestrointi, audit-loki, watchdog) toimii OIKEIN
   ERIKSEEN.
2. **Integraatiotestit** paljastivat AIDON RTL-virheen
   (`AUDIT_WORD_SEL`-osoitteen puuttuva kirjoituskasittely) jota
   MIKAAN yksikkotesti ei olisi voinut loytaa, koska vika syntyi
   VASTA kahden komponentin jaetusta tilasta.
3. **Regressiotesti todistettiin toimivaksi** palauttamalla loydetty
   bugi TARKOITUKSELLA (poistamalla korjaus valiaikaisesti) ja
   varmistamalla etta testi TODELLA epaonnistuu tallöin - ei vain
   nimellisesti, vaan aidosti herkka juuri tallle virheelle.
4. **CI vahvisti riippumattomasti** etta korjattu toteutus lapaisee
   kaikki testit.

Tama nelivaiheinen ketju - erityisesti vaihe 3 - on se mika erottaa
"testin joka on olemassa" testista "joka aidosti suojaa jotakin".

## Mita on nyt valmiina ja todennettu

| Komponentti | Tila |
|---|---|
| Wishbone-vaylaohjaus (osoitekartta 0x000-0x129) | ✅ |
| ML-KEM.KeyGen_internal -orkestrointi (synteesikelpoinen RTL) | ✅ |
| Hash-ketjutettu audit-loki (SHA3-256-pohjainen) | ✅ |
| Watchdog/heartbeat-valvonta | ✅ |
| Watchdogin integrointi virhepolulle (audit-lokitus) | ✅ |
| Onnistumispolun paasta-paahan-testi (ECU->TAU->ECU) | ✅ |
| Virhepolun paasta-paahan-testi (watchdog keskeyttaa KeyGenin) | ✅ |
| Audit-lokin monisanaluvun regressiotesti | ✅ |
| CI-integraatio (kolme testia, automaattisesti ajettuna) | ✅ |

## Mita EI viela ole tehty (tietoisesti rajattu, ei unohdettu)

- ML-KEM.Encaps_internal ja ML-KEM.Decaps_internal -orkestrointi
- Taysi synteesi + P&R -vahvistus ECP5:lla (blokkautuu resurssi-
  raskaan Keccak-instanssien maaran vuoksi - tunnettu, dokumentoitu
  rajoitus, ei korrektiusongelma)
- Dilithium (M5-DILITHIUM-001, GitHub Issue #17)

## Miksi tama rajaus on tarkeaa seuraavalle vaiheelle

Decaps ei enaa ole infrastruktuuriprojekti - se on kryptografisen
algoritmin integrointi OLEMASSA OLEVAAN, jo todennettuun kehykseen.
Tyo voi keskittya lahes kokonaan:

- ML-KEM.Decaps_internal-tilakoneeseen
- FO-muunnoksen (Fujisaki-Okamoto) logiikkaan
- K-PKE.Decrypt- ja re-encrypt-vaiheisiin
- virhepolkujen (implisiittinen hylkays) oikeellisuuteen

Wishbone, audit-loki, watchdog ja CI-testauskehys voidaan hyodyntaa
sellaisenaan. Tama selkea rajaus tekee myohemmasta kehityshistoriasta
seurattavamman: jos Decaps- tai Dilithium-tyossa loytyy virheita,
ne voidaan analysoida ilman epaselvyytta siita, johtuivatko ne
palvelukehyksesta vai itse kryptografisesta toteutuksesta.

## Seuraava tyopaketti

**M4-DECAPS-ORCH-001** (ei viela GitHub Issueta - luodaan seuraavaksi):
ML-KEM.Decaps_internal-orkestrointi, samalla vaiheittaisella
testausmenetelmalla kuin KeyGenissa (M4-MLKEM-ORCH-001).
