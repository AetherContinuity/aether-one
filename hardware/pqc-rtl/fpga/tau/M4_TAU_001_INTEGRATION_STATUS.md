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
