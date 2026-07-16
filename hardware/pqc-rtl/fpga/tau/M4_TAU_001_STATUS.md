# M4-TAU-001: TAU-audit-loki (D4-yhteensopivuus) - Osa 1 VALMIS

**Paivamaara:** 2026-07-19
**Tila:** Audit-loki (hash-ketjutus + lukurajapinta) TOIMII,
todennettu Python-referenssia vasten.

## Toteutus

`pqc_tau_audit_log.sv` - D4 (Audit Continuity) -yhteensopiva
hash-ketjutettu audit-loki. Kayttaa UUDELLEEN jo olemassa olevaa,
todennettua SHA3-256-ydinta (pqc_sha3_256.sv, M3 Issue #12) - ei
uutta kryptografista primitiivia.

**Ketjutuskaava:** `chain_hash[n] = SHA3-256(chain_hash[n-1] ||
decision_hash[n] || seq[n])` - muuttumaton, tamperoinnin paljastava
ketju (klassinen hash-chain-periaate).

## Loydetty ja korjattu bugi: tavujarjestyskonventio

Ensimmainen testiajo epaonnistui - chain_hash ei tasmannyt Python-
referenssiin. Juurisyy loydettiin tarkastelemalla projektin OMAA,
jo vakiintunutta `pack_bytes()`-konventiota
(m2-golden/gen_sha3_256_vectors.py): tavu 0 sijoittuu VAHITEN
merkitsevaksi tavuksi (`val |= byte << (i*8)`), EI tavanomaista
`.hex()`-jarjestysta.

Korjaus: msg_in-konkatenaation jarjestys vaihdettu
`{seq_counter, decision_hash_reg, current_chain_head}` (chain_head
ALIMPANA, matkien pack_bytes-konventiota), ja Python-golden-referenssi
generoitu kayttaen samaa `pack_bytes()`-funktiota kuin projektin muu
SHA3-testivektorien generointi.

## Todennettu

- Kolme perakkaista audit-loki-merkintaa kirjoitettu, chain_hash
  tasmaa Python-referenssiin JOKAISESSA merkinnassa.
- Lukurajapinta (deferred reconciliation - TN-002:n oma vaatimus:
  paikallinen loki, luettavissa myohemmin ilman ulkoista yhteytta)
  palauttaa oikean datan jokaiselle merkinnalle.

## Jaljella (M4-TAU-001:n loput osat)

1. Watchdog/heartbeat-logiikka ECU<->TAU-viestintaa varten
2. Attestaatioprotokollan runko (ECU submitoi decision_hash -> TAU
   validoi -> TAU lokittaa) - VAIN hash-commitment tassa vaiheessa,
   EI taytta Dilithium-allekirjoitusta (M5:n oma tyo)
3. Integraatio olemassa olevaan Wishbone-vaylakaareen (M4-SoC-001)
4. Istuntoavaimen muodostus ML-KEM:n kautta (VERA Agent: "Kyber for
   key exchange") - vaikeampi, laajempi osa, todennakoisesti oma
   valivaihe

## Osa 2: Wishbone-integraatio VALMIS (2026-07-19)

`pqc_tau_wishbone_wrapper.sv` yhdistaa NTT-ytimen (M4-SoC-001) ja
audit-lokin (Osa 1) SAMAAN Wishbone-vaylaan. 256-bittiset hash-arvot
pakataan/puretaan 16:sta perakkaisesta 16-bittisesta sanasta
(AUDIT_WORD_SEL osoittaa senhetkisen sanan).

**Osoitekartta laajennettu:**
- 0x000-0x0FF: NTT-data (ennallaan)
- 0x100-0x107: NTT-ohjaus/tila (ennallaan)
- 0x110-0x119: Audit-loki (uusi) - AUDIT_WORD_SEL, AUDIT_HASH_IN,
  AUDIT_COMMIT, AUDIT_STATUS, AUDIT_SEQ, AUDIT_CHAIN_OUT,
  AUDIT_READ_SEQ, AUDIT_READ_VALID, AUDIT_READ_CHAIN, AUDIT_READ_DECISION

**Todennettu (pqc_tau_wishbone_tb.sv):**
- decision_hash kirjoitettu 16 sanana Wishbone-kirjoituksilla
- Audit-lokin kirjoitus laukaistu, valmistui 15 Wishbone-syklin
  sisalla
- chain_hash luettu takaisin 16 sanana, TASMAA Python-golden-
  referenssiin
- NTT-datan luku/kirjoitus TOIMII EDELLEEN samassa yhdistetyssa
  kaareessa (ei regressiota)

**PASS: audit-loki + NTT-ydin integroitu samaan vaylaan, molemmat
toimivat oikein.**

## Jaljella (M4-TAU-001:n loput osat)

1. Watchdog/heartbeat-logiikka ECU<->TAU-viestintaa varten
2. Taydempi attestaatioprotokolla (viela vain hash-commitment,
   EI Dilithium-allekirjoitusta - M5:n oma tyo)
3. Istuntoavaimen muodostus ML-KEM:n kautta (VERA Agent: "Kyber
   for key exchange")
4. Synteesi + P&R -vahvistus ECP5:lla (kuten M4-SoC-001:lle tehtiin)

## Osa 3: Watchdog/heartbeat VALMIS (2026-07-19)

`pqc_tau_watchdog.sv` - ECU<->TAU-heartbeat-seuranta TN-002:n oman
"Watchdog System" -kuvauksen mukaisesti: "failures are detected and
logged even when the operational unit is compromised... enters
degraded mode gracefully rather than failing silently."

**Keskeiset suunnittelupaatokset:**
- Konfiguroitava aikakatkaisukynnys (sykleina)
- Degraded-tila (`ecu_alive=0`) EI palaudu automaattisesti pelkalla
  uudella heartbeatilla - tarkoituksellinen: kertaalleen havaittu
  vika ei saa kadota hiljaa ilman eksplisiittista kuittausta
  (TN-002:n oma periaate: ei "failing silently")
- `timeout_count` sailyttaa historian montako aikakatkaisua on
  tapahtunut

**Todennettu (pqc_tau_watchdog_tb.sv), nelja vaihetta:**
1. Saannollinen heartbeat pitaa ecu_alive=1
2. Puuttuva heartbeat laukaisee aikakatkaisun tasmalleen oikealla
   syklilla (rekisterointiviive huomioitu)
3. Degraded-tila ei palaudu automaattisesti
4. Konfiguroitava aikakatkaisukynnys toimii oikein

**Loydetty vain testipenkin oma ajoitusongelma** (liian lyhyt reset-
pulssi valitesteissa aiheutti tilan sekoittumisen edellisesta
vaiheesta) - EI RTL-bugia. Korjattu pidentamalla reset-pulssia ja
tarkentamalla odotettuja sykliaikoja rekisterointiviiveen mukaisesti.

## M4-TAU-001:n tila

| Osa | Tila |
|---|---|
| 1. Audit-loki (hash-ketjutus + lukurajapinta) | ✅ VALMIS |
| 2. Wishbone-integraatio (audit-loki + NTT-ydin) | ✅ VALMIS |
| 3. Watchdog/heartbeat | ✅ VALMIS |
| 4. Watchdogin integrointi audit-lokiin (automaattinen lokitus aikakatkaisusta) | Seuraava |
| 5. ML-KEM-pohjainen istuntoavaimen muodostus | Seuraava |
| 6. Synteesi + P&R -vahvistus ECP5:lla | Seuraava |
