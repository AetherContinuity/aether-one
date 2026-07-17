# M4-TAU-001: paasta-paahan-integraatio VALMIS

**Paivamaara:** 2026-07-19
**Tila:** PASS - koko ketju ECU->Wishbone->KeyGen->audit-loki->ECU
toimii todistetusti.

## Kayttajan sovittu integraatiojarjestys, toteutettu tasmalleen

1. **Wishbone -> KeyGen**: START-rekisteri (0x123), BUSY/DONE-tila-
   rekisteri (0x124), sana-kohtainen luku/kirjoitus 16-bittisen
   vaylan yli (0x120 WORD_SEL + 0x121/0x122 seed-syote, 0x125/0x126
   ek/dk-luku).
2. **KeyGen -> audit-loki**: kaksi tapahtumaa KIINTEILLA tunniste-
   hasheilla (SHA3-256("KEYGEN_STARTED_EVENT") /
   SHA3-256("KEYGEN_COMPLETED_EVENT")) - EI kryptografista avain-
   materiaalia lokiin, vain ennalta tunnetut tapahtumamerkit.
3. **ECU<->TAU-rajapinta**: ECU kirjoittaa d_seed+z_seed 16 sanana,
   laukaisee KEYGEN_START, pollaa KEYGEN_STATUS:ia, lukee ek (400
   sanaa) ja dk (816 sanaa) takaisin - KOKO KETJU testattu paasta
   paahan.

## Toteutus: pqc_tau_integrated_wrapper.sv

Yhdistaa: NTT-ytimen (M4-SoC-001), audit-lokin (M4-TAU-001 Osa 1/2),
KeyGen-orkestraattorin (M4-MLKEM-ORCH-001) SAMAAN Wishbone-vaylaan.

## Testitulokset (pqc_tau_integrated_tb.sv)

```
ECU: d_seed + z_seed kirjoitettu Wishbone-vaylan kautta
ECU: KEYGEN_START laukaistu
OK: KeyGen valmis 3780 Wishbone-syklin jalkeen
PASS: ek tasmaa taydellisesti Wishbone-vaylan kautta luettuna
PASS: dk tasmaa taydellisesti Wishbone-vaylan kautta luettuna
OK: audit-loki sisaltaa tasan kaksi merkintaa (KeyGen kaynnistetty + valmis)
PASS: TAU-integraatio - ECU->Wishbone->KeyGen->audit-loki->ECU koko ketju toimii
```

**KAIKKI TARKISTUKSET LAPAISEVAT.**

## Kayttajan oma huomio toteutettu: audit-lokin sisalto

Audit-lokiin kirjataan VAIN tapahtumat (kaynnistys, valmistuminen),
EI kryptografista avainmateriaalia - vastaa tasmalleen kayttajan
omaa vaatimusta: "Kryptografisen avainmateriaalin sisaltoa ei
tietenkaan pida kirjata, mutta tapahtumat ... ovat hyodyllisia
seka diagnostiikan etta jaljitettavyyden kannalta."

## Watchdogin oma integrointi tahan kokonaisuuteen

**EI VIELA TEHTY tassa kierroksessa** - taman integraation
`pqc_tau_integrated_wrapper.sv` EI VIELA sisalla watchdog-instanssia
(vain audit-loki + KeyGen + NTT). Watchdogin oma "KeyGen epaonnistui/
watchdog keskeytti" -tapahtuma (kayttajan oma nelja kohta) on
seuraava, pieni lisays taman jo toimivan perustan paalle.

## Seuraavat askeleet (kayttajan oma priorisointi)

1. ✅ **M4-TAU-001 integraation viimeistely** - PAAOSA VALMIS
   (Wishbone+KeyGen+audit toimivat yhdessa). Watchdogin oma
   integrointi (KeyGen-epaonnistumisen lokitus) viela puuttuu -
   pieni, hyvin rajattu lisatyo.
2. ✅ **Ensimmainen paasta-paahan-demo** - VALMIS JA TODENNETTU
   (tama dokumentti).
3. ⏭️ **Decaps-orkestraattori** - seuraava, samalla vaiheittaisella
   menetelmalla kuin KeyGenissa.
4. ⏭️ **Dilithium (#17)** - vasta ML-KEM-ketjun ollessa kokonaan
   valmis.

## Watchdog integroitu virhepolulle - VALMIS (2026-07-19, jatko)

**Kayttajan oma nakemys toteutettu tasmalleen:** watchdog on nyt
integroitu koko TAU-kokonaisuuteen, kattaen SEKA onnistuneen etta
epaonnistuneen KeyGen-suorituksen:

1. KeyGen kaynnistyy -> audit-lokiin
2. **Joko** KeyGen valmistuu onnistuneesti (audit-lokiin) **tai**
   watchdog katkaisee suorituksen (audit-lokiin, ERI tunnistehashilla)
3. ECU nakee lopputilan Wishbone-rajapinnasta (WATCHDOG_STATUS 0x129)

**Uudet Wishbone-rekisterit:**
- 0x127: HEARTBEAT (ECU:n oma elossaolomerkki)
- 0x128: WATCHDOG_TIMEOUT_CONFIG (aikakatkaisukynnys sykleina)
- 0x129: WATCHDOG_STATUS (luku): [0]=ecu_alive [1]=watchdog_keskeytys_kesken_keygenin

**Loydetty ja korjattu kaksi bugia matkalla:**
1. Oma testisuunnitteluvirhe: liian lyhyt (100 sykli) aikakatkaisu
   laukesi jo siementen latauksen aikana, ennen KeyGenin omaa
   kaynnistysta - korjattu kasvattamalla aikakatkaisua (1000 sykli).
2. **Todellinen RTL-bugi:** `AUDIT_WORD_SEL` (osoite 0x110) ei ollut
   koskaan kytketty paivittamaan jaettua `word_sel`-rekisteria -
   vain `KEYGEN_WORD_SEL` (0x120) teki taman. Tama aiheutti sen
   etta audit-lokin lukurajapinta AINA palautti VIIMEISIMMAN
   kaytetyn word_sel-arvon (KeyGenin omasta kayttajasta jaanytta),
   EI oikeaa, pyydettya sanaa. Korjattu lisaamalla puuttuva
   kirjoituskasittely.

**Todennettu (pqc_tau_watchdog_interrupt_tb.sv):**
- Watchdog laukeaa oikein kun ECU lakkaa lahettamasta heartbeatia
  KESKEN KeyGenin oman ajon
- Audit-loki sisaltaa TASMALLEEN kaksi merkintaa (kaynnistys +
  watchdog-keskeytys) - EI "KeyGen valmis" -merkintaa, koska sita
  ei koskaan saavutettu
- Toinen merkinta on NIMENOMAAN oikea, erillinen tunnistehash
  (erottuu selvasti "KeyGen valmis" -hashista)

**Ei regressiota:** alkuperainen paasta-paahan-testi (onnistunut
KeyGen-ajo) PASSAA edelleen taydellisesti.

## M4-TAU-001: PALVELUKEHYS VALMIS

Kayttajan oma kuvaus toteutunut: "TAU:n 'palvelukehys' on kaytannossa
valmis." Kaikki nelja peruspalvelua (Wishbone-vayla, KeyGen-
orkestrointi, audit-loki, watchdog) toimivat YHDESSA, seka
onnistumis- etta virhepolulla, ja Decaps voidaan seuraavaksi
rakentaa SAMAN kehyksen sisaan ilman rajapintamuutoksia.

**Kayttajan oma etenemisjarjestys:**
1. ✅ Wishbone <-> KeyGen
2. ✅ Audit-loki
3. ✅ Watchdog loppuun asti integroituna myos virhepolulle
4. ⏭️ Decaps-orkestraattori (seuraava)
5. ⏭️ Dilithium (#17)
