# M4-ENCAPS-ORCH-001: ML-KEM.Encaps_internal synteesikelpoinen orkestrointi

**Paivamaara:** 2026-07-19
**Tila:** VALMIS ensimmaisella yrityksella, hyodyntaen suoraan
Decapsin todistettua koodia.

## Miksi tama valmistui niin nopeasti

ML-KEM.Encaps_internal (FIPS 203 Algoritmi 17) on rakenteeltaan:
1. H(ek) = SHA3-256(ek, 800 tavua)
2. (K,r) = G(m||H(ek)) = SHA3-512
3. c = K-PKE.Encrypt(ek, m, r)

Vaihe 3 (K-PKE.Encrypt) ON TASMALLEEN SAMA algoritmi jota Decapsin
Phase B1-B3 jo kayttaa (Decaps tarvitsee K-PKE.Encrypt:n re-encrypt-
vaiheessaan FO-muunnoksen omana osana). Tama mahdollisti SUORAN
uudelleenkayton: `pqc_mlkem_encaps_top.sv` instantioi
`pqc_mlkem_decaps_b1_core.sv`:n SELLAISENAAN K-PKE.Encrypt-moottorina,
syottaen Decapsin OMAT FO-valintaan liittyvat portit (c_in/z_in/
K_prime_in) nollilla (nama EIVAT vaikuta c':n omaan laskentaan - vain
Phase B4:n OMAAN, erilliseen FO-paatokseen, jota tama moduuli ei kayta).

## Toteutus

`pqc_mlkem_encaps_top.sv`: SHA3-256(H) -> SHA3-512(G) -> uudelleen-
kaytetty K-PKE.Encrypt (decaps_b1_core) -> (K,c).

## Testitulos (TUOREELLA, riippumattomalla vektorilla)

```
Valmis 14403 syklin jalkeen
OK: K tasmaa taydellisesti golden-malliin
PASS: c tasmaa taydellisesti golden-malliin
PASS: koko Encaps-huippumoduuli - K ja c tasmaavat taydellisesti
```

**PASS TAYDELLISESTI ENSIMMAISELLA YRITYKSELLA - EI YHTAAN LOYDETTYA
BUGIA.** Tama on suora todiste siita etta huolellisesti todistettu,
uudelleenkaytettava koodi (K-PKE.Encrypt Decapsista) sailyttaa
oikeellisuutensa myos UUDESSA kontekstissa (Encaps), kunhan
rajapinnat (portit, jotka EIVAT liity uudelleenkaytettyyn logiikkaan)
kasitellaan huolellisesti.

## M4-ENCAPS-ORCH-001:n tila

| Osa | Tila |
|---|---|
| H(ek), G(m\|\|H) | ✅ |
| K-PKE.Encrypt (uudelleenkaytetty Decapsista) | ✅ |
| Yhdistetty huippumoduuli | ✅ |
| Wishbone-integraatio | ❌ Seuraava |
| Synteesi + P&R | ❌ |

Metodologinen huomio: taman tyopaketin nopeus (yksi kierros, ei
bugeja) verrattuna KeyGenin ja Decapsin omiin, huomattavasti
pidempiin debug-matkoihin, havainnollistaa suoraan projektin
kypsymista - aiemmin rakennettu, huolellisesti todistettu
infrastruktuuri ja logiikka tuottavat konkreettista hyotya
uusissa tyopaketeissa.
