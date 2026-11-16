# B8: Decapsin ajoitus- ja toggle-otoksen laajennus — ennakkorekisteröinti

**Kirjattu:** 2026-11-16, ennen yhtään tämän otoksen mittausta.
Commit, joka lisää tämän tiedoston, edeltää mittauskoodia ja tuloksia.
Muutokset tähän tiedostoon tuloksen jälkeen ovat poikkeamia, ja ne kirjataan
erilliseen `B8-POIKKEAMA-N.md`-tiedostoon.

## Lähtötilanne (KORJAUSLISTA B7, B8)

Aiempi väite (`M3_MLKEM_ACVP_STATUS.md`, 2026-07-22): Decaps on syklitasolla
vakioaikainen salaisen datan suhteen, ja valinta-/vertailumekanismi ei lisää
bittikytkentää valitun ehdokkaan päälle. Otos: yksi avain (K=2, tcId=76), yksi
valid/hylkäys-pari, korruptio yksi tavu.

## Kohde

`pqc_mlkem_decaps_top` (Phase A: `pqc_mlkem_decaps_a_core`, Phase B:
`pqc_mlkem_decaps_b1_core`), K=2 ja K=3, Icarus Verilog -simulaatio. Ei
teho-, EM- tai porttitason mittausta.

## Otos

Avaimet: kaikki NIST ACVP:n decapsulation-tapausten dk:t (975de31): K=2
tcId 76–85, K=3 tcId 86–95; 10 + 10 avainta. `fpga/tau/acvp/decaps_{512,768}.txt`.

Jokaiselle avaimelle ciphertext-muunnelmat:

| Tunnus | Muunnelma |
|---|---|
| V | validi c. NIST:n valid-tapauksessa sen oma c; NIST:n hylkäystapauksessa c = Encaps(ek, m), ek dk:sta, m = SHA3-256("B8" ‖ tcId) (golden-malli) |
| R0 | V, tavu 0 XOR 0x01 (c1:n alku) |
| R1 | V, viimeinen tavu XOR 0x80 (c2:n loppu) |
| R2 | V, c1:n keskimmäinen tavu XOR 0x10 |
| R3 | V, c2:n ensimmäinen tavu XOR 0xFF |
| RN | NIST:n oma muokattu c (vain NIST:n hylkäystapauksissa) |

Lisäksi salaisuuden vaihto (H2): jokaiselle avaimelle i dk'ᵢ =
dkPKE₍ᵢ₊₁₎ ‖ ekᵢ ‖ H(ekᵢ) ‖ z₍ᵢ₊₁₎ (indeksi mod 10 saman K:n sisällä), syötteenä
avaimen i V-ciphertext. Julkinen osa (ek, H(ek), c) pysyy, salainen osa
(s, z) vaihtuu.

## Hypoteesit ja hylkäyssäännöt

**H1 (syklitaso, salainen data / c:n sisältö).** Jokaiselle avaimelle kaikki
muunnelmat (V, R0–R3, RN) antavat tasan saman Phase A -, Phase B - ja
kokonaissyklimäärän. *Hylätään*, jos yhdenkin avaimen yhdessäkin muunnelmassa
jokin kolmesta luvusta eroaa V:stä vähintään yhden syklin.

**H2 (syklitaso, salainen avain).** dk'ᵢ antaa tasan saman Phase A -, Phase B -
ja kokonaissyklimäärän kuin dkᵢ samalla c:llä. *Hylätään*, jos yksikin ero.

**H3 (avainten välinen vaihtelu on julkista).** Kokonaissyklimäärä saa vaihdella
avainten välillä. Ennuste: vaihtelu on kokonaan ExpandA:n (SampleNTT,
syöte ρ) vaihtelua. Testi: H2:n parit erottavat ρ:n ja salaisuuden; jos H2
pätee, avainten välinen ero ei riipu salaisuudesta. Tätä ei testata erikseen.

**H4 (toggle, valintamekanismi).** `decaps_b`-scopessa, tämän otoksen
toggle-osajoukossa (alla), `K_final_out`:n bittikytkentämäärä on tasan sama
kuin valitun ehdokkaan (V: `K_prime_in`, hylkäys: `shake256_out`) oma määrä.
*Hylätään*, jos yhdessäkin ajossa ero ≠ 0. Mittari:
`toggle-proxy/count_toggles.py` (validoitu, `TOGGLE-PROXY-VALIDATION.md`).
Toggle-osajoukko: K=2 ja K=3, kummastakin 3 ensimmäistä avainta × (V, R0, R3)
= 18 ajoa.

**H5 (oikeellisuus, ei sivukanava).** Jokaisessa ajossa `K_final_out` on sama
kuin golden-mallin `mlkem_decaps_internal`. H1:n ajoissa `match_out` = 1 tasan V:llä; H2:n ajoissa `match_out`:ia verrataan golden-mallin c == c'-tulokseen.
Tämä on edellytys: jos H5 ei päde, H1–H4 jätetään tulkitsematta.

## Mitä tämä ei kerro

- Ei tehoa, EM:ää eikä porttitason glitchejä (RTL-simulaatio).
- H4 ei koske ulostuloarvon omaa Hamming-painoa: se on eri kysymys (B7, maskaus).
- Otos on NIST:n 20 avainta. Se ei ole satunnaisotos avainavaruudesta.
- Synteesityökalu voi muuttaa rakennetta. Väite koskee RTL:ää.
