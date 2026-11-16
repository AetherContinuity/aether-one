# B8: tulos

**Ajettu:** 2026-11-16. Ennakkorekisteröinti: `B8-ENNAKKO.md` (commit 32d37ff).
Mittauskoodi: commit f7a8872, molemmat ennen ensimmäistä ajoa.
Ajo: `run_b8_sivukanava.sh --vaadi`. Negatiivikontrollit: `sivukanava/b8_negkontrollit.sh`.
Poikkeamia ennakkorekisteröinnistä ei ole. Ainoa muutos koodiin ennen tätä
tulosta: käännöstiedoston nimi ajokohtaiseksi (rinnakkaiset negatiivikontrollit
kirjoittivat samaan tiedostoon) ja arviointiskriptin argumenttijärjestys. Kumpikaan
ei koske hypoteeseja tai hylkäyssääntöjä.

## Tulos

| Hypoteesi | Tulos | Vertailuja |
|---|---|---|
| H5 oikeellisuus (K_final = golden, match odotettu) | pätee | 130/130 ajoa |
| H1 syklit: c:n muunnelmat (R0–R3, RN) vs V samalla avaimella | pätee | 90/90 |
| H2 syklit: vaihdettu salaisuus (s, z) vs V, sama julkinen osa | pätee | 20/20 |
| H4 toggle: `K_final_out` = valitun ehdokkaan bittikytkennät | pätee | 18/18 ajoa, ero 0 kaikissa |

H1 ja H2 tarkoittavat: Phase A -, Phase B - ja kokonaissyklimäärä on sama
viimeistä sykliä myöten.

Avainten välinen vaihtelu (V-ajot):

| | Phase A | Phase B | Kokonais |
|---|---|---|---|
| K=2, 10 avainta | 7666 kaikilla | 14171–14203 (10 eri) | 21839–21871 |
| K=3, 10 avainta | 10036 kaikilla | 20737–20789 (9 eri) | 30775–30827 |

Phase A (purku, NTT, sisätulo, G) on avaimesta riippumaton. Vaihtelu on
kokonaan Phase B:ssä, joka sisältää ExpandA:n (SampleNTT, syöte ρ). H2:n
mukaan vaihtelu ei muutu, kun salaisuus vaihdetaan ja ρ pidetään. Tämä on
yhteensopiva H3:n kanssa (vaihtelu julkista), mutta H3:a ei testattu
erikseen, kuten ennakkoon kirjattiin.

## Negatiivikontrollit (mittari pystyy hylkäämään)

Kolme tarkoituksella vuotavaa muunnelmaa `pqc_mlkem_decaps_b1_core.sv`:stä, K=2:

| Muunnelma | Vuoto | Odotettu hylkäys | Tulos |
|---|---|---|---|
| L1 | matchilla K_bar:ia ei lasketa (aikainen poistuminen) | H1 | hylättiin, 0/45 |
| L2 | +1 sykli, jos z[0] = 1 (salaisuusriippuva) | H2 | hylättiin, 6/10 |
| L3 | K_final_out ← K' aina, hylkäyksessä korvataan seuraavalla syklillä | H4 | hylättiin, 9/9 |

L2:n 6/10 on odotettu: vuoto näkyy vain pareissa, joissa z[0] eroaa.

## Tulkinta (tarkka muotoilu)

RTL-simulaatiossa, tällä otoksella (20 NIST-avainta, K=2 ja K=3, 5–6
ciphertext-muunnelmaa ja yksi salaisuudenvaihto per avain): **Decaps on
syklitasolla vakioaikainen salaisen datan (s, z) ja ciphertextin sisällön
suhteen**, ja **valintamekanismi ei lisää bittikytkentää valitun ehdokkaan
päälle**. Mittari havaitsi kaikki kolme tarkoituksella lisättyä vuotoa.

## Rajaukset

- RTL-simulaatio. Ei tehoa, EM:ää, porttitason glitchejä eikä synteesin
  jälkeistä rakennetta.
- H4 mittaa yhtä rekisteriä ja sen lähdettä. Se ei kata koko Decapsin
  datariippuvaa kytkentäaktiivisuutta (esim. NTT, Keccak). Ulostuloarvon oma
  Hamming-paino on eri kysymys (B7, maskaus).
- Otos on NIST:n 20 avainta, ei satunnaisotos. Muunnelmat ovat yhden tavun
  tai bitin muutoksia neljässä kohdassa sekä NIST:n omat muokatut ciphertextit.
- Vanha mittaus (2026-07-22, `M3_MLKEM_ACVP_STATUS.md`) käytti NIST:n
  esimerkkitiedoston aiempaa versiota (KORJAUSLISTA A10). Sen tcId-numerot
  eivät viittaa samoihin tapauksiin kuin tämän otoksen: commitin 975de31
  tcId=76 on muokattu ciphertext, vanhan tiedoston tcId=76 oli validi.
  Syklimääriä ei voi verrata suoraan.
