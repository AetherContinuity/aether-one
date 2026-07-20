# Representation Contract (M5-DILITHIUM-001 / ML-DSA-65)

Tama dokumentti maarittaa YKSIKASITTEISESTI, missa esitysmuodossa
jokainen ML-DSA-65-toteutuksen keskeinen suure ("rho", "z", "t0",
"c" jne.) kulkee jokaisen rajapinnan yli. Se on kirjoitettu
2026-07-20, sen jalkeen kun useampi loydetty "bugi" tassa projektissa
osoittautui algoritmivirheen sijaan **esitysmuotojen yhteen-
sovittamisen** ongelmaksi kahden muuten oikein toimivan komponentin
valilla (ks. DK6_STATUS.md, jatko-osat 16 ja 19).

**Miksi tama dokumentti on olemassa:** valtaosa taman projektin
myohaisen vaiheen loydoksista EI ollut kryptografisia virheita, vaan
representaatioeroja - esim. "onko z Zq-edustaja [0,Q) vai keskitetty
etumerkillinen luku" tai "onko t0 kaksoiskomplementti vai Zq-muoto".
Molemmat esitykset OVAT PATEVIA matemaattisesti, mutta VAIN YKSI
niista on OIKEA tietylle rajapinnalle. Kun kaksi muuten oikein
toimivaa moduulia yhdistetaan ERI OLETUKSIN, seurauksena on hiljainen,
vaikeasti loydettava virhe - EI kaannosvirhe eika simulointivirhe.

## Perusmaaritelmat

- **Zq-edustaja ("Zq form")**: kokonaisluku valilla `[0, Q)`, missa
  `Q = 8380417`. Negatiiviset arvot esitetaan muodossa `Q + arvo`.
  Tama on NTT:n ja Barrett-aritmetiikan oma sisainen tyoskentely-
  muoto.
- **Keskitetty etumerkillinen ("centered signed")**: kokonaisluku
  joka voi olla suoraan negatiivinen (esim. -377156), tyypillisesti
  paljon pienempi arvoalue kuin Q (esim. z: ±524288, t0: ±4096).
  Tama on FIPS 204:n oma pakkauskaavojen ("altered=GAMMA1-z" jne.)
  olettama muoto.
- **Kaksoiskomplementti-kentta ("two's complement field")**: N-
  bittinen rekisteri jossa negatiivinen arvo esitetaan standardi-
  Verilog-tavalla (`raw[N-1]`=etumerkkibitti). TAMA ON SAMA ASIA
  kuin "keskitetty etumerkillinen" kun arvo mahtuu kenttaan - mutta
  ERI ASIA kuin Zq-edustaja, vaikka molemmat ovat N-bittisia
  unsigned-kentan sisalla RTL:ssa.

## Rajapintataulukko

| Suure | Lahde | Kohde | Esitysmuoto | Leveys | Huomio |
|---|---|---|---|---|---|
| `rho`, `rho_prime`, `tr`, `K_key` | SHAKE256-ulostulo | mika tahansa kayttaja | little-endian tavujono (tavu0=LSB) | 32/64 tavua | Sama konventio kuin `pack_bytes()`: `arvo \|= tavu << (i*8)` |
| `s1`, `s2` | `ExpandS` (RTL: `pqc_dilithium_expand_s.sv`) | `sign_z_core`, `sign_hint_core` | **etumerkillinen 8-bit/kerroin** RAAKANA ExpandS:sta, MUUNNETTAVA Zq-muotoon ENNEN kayttoa | 8 bit/kerroin (raaka), 23 bit/kerroin (Zq, CW) | Muunnos: `(raw<0) ? Q+raw : raw` |
| `t0` | `Power2Round` (RTL: `pqc_dilithium_power2round.sv`) | `sign_hint_core` | **keskitetty etumerkillinen** kaksoiskomplementti, arvoalue `(-2^(D-1), 2^(D-1)]` = `(-4096,4096]` | 23 bit (CW), mutta VAIN pieni osa kaytossa | MUUNNETTAVA Zq-muotoon ennen NTT-kayttoa: `(raw<0) ? Q+raw : raw`. LOYDETTY JA KORJATTU `stage2_sign_tb.sv`:ssa 2026-07-20 (jatko 19). |
| `y` | `ExpandMask` (RTL: `pqc_dilithium_expand_mask_vector.sv`) | `sign_top2.sv`:n oma `y_reg` | **keskitetty etumerkillinen**, arvoalue `(-(GAMMA1-1), GAMMA1]` | 24 bit (ZW) | `sign_top2.sv` MUUNTAA taman Zq-muotoon (`y_zq`) ENNEN `sign_w_core`:n kayttoa - `sign_z_core` KUITENKIN kayttaa alkuperaista keskitettya `y_reg`:ia suoraan. |
| Sign:n sisainen NTT-laskenta (`s1_hat`, `s2_hat`, `t0_hat`, `y_hat`, `c_hat`, `w`, `c_s1`, `c_s2`, `c_t0` jne.) | eri | eri | **Zq-edustaja** [0,Q) LAPI KOKO NTT-PUTKEN | 23 bit (CW) | Tama on `pqc_dilithium_ntt_core.sv`/`barrett_mulmod.sv`:n oma, ainoa hyvaksytty muoto. |
| `z` | `sign_z_core.sv` (`y+c*s1`) | `sign_top2.sv`:n oma `z_out_flat`/`z_reg` | **Zq-edustaja** [0,Q) | 24 bit (ZW, mutta arvo mahtuu Zq-alueeseen) | TAMA ON SE PISTE JOSSA MUUNNOS UNOHTUI ALUNPERIN (ks. jatko 16). |
| `z` ENNEN `pack_z`/`pack_sig`-kutsua | `sign_top2.sv`:n `z_out_flat` (Zq) | `pqc_dilithium_pack_z_vector.sv` | **PAKOLLINEN MUUNNOS Zq -> keskitetty** ennen tata rajapintaa: `(z_raw > (Q-1)/2) ? z_raw-Q : z_raw` | 24 bit | LOYDETTY NIST ACVP sigGen -testivektorilla 2026-07-20 (jatko 16). Korjaus TESTIPENKIN/integraatiotason kytkennassa, EI `pack_sig.sv`:n sisalla (pack_sig.sv:n oma S8-testi kaytti jo valmiiksi keskitettya dataa). |
| `pack_z`:n ulostulo | `pqc_dilithium_pack_z.sv` | allekirjoituksen `z`-osa (3200 tavua) | FIPS 204:n oma tiukka 20-bit/kerroin -pakkaus (`altered=GAMMA1-z`) | 20 bit/kerroin pakattuna | Symmetrinen `unpack_z`:n kanssa (sama kaava toimii molempiin suuntiin). |
| `w1 = HighBits(w)` | `Decompose` (RTL: `pqc_dilithium_decompose.sv`) | `pack_w`, `SampleInBall`:n oma SHAKE-syote, `UseHint` | pieni etumerkitön arvo, `r1_out` | 4 bit/kerroin (K=6:lla `ALPHA`-jaolla) | EI Zq-edustaja eika keskitetty - oma, pieni arvoalue `Decompose`-algoritmin maarittelema. |
| `c` (SampleInBall:n RAAKA ulostulo) | `pqc_dilithium_sample_in_ball.sv` | `sign_z_core`, `sign_hint_core`:n oma NTT-muunnos | **etumerkillinen** `{-1,0,1}` | 8 bit/kerroin | MUUNNETTAVA Zq-muotoon (`(raw<0)?Q+raw:raw`) ENNEN forward-NTT:ta - tama muunnos ON JO OIKEIN toteutettu jokaisessa `c`:ta kayttavassa moduulissa (`sign_z_core.sv`, `sign_hint_core.sv`, `verify_core.sv`:n oma `c_zq`-generate-lohko). |
| `c_tilde` | SHAKE256(mu\|\|w1_bytes, 48) | allekirjoituksen ensimmainen osa, `SampleInBall`:n oma syote | 48-tavuinen digest, little-endian tavujono | 384 bit | Sama konventio kuin `rho`/`tr`. |
| `h` (hint) SISAINEN RTL-esitys | `MakeHint`/`sign_hint_core.sv`, `unpack_h.sv` | `pack_h.sv`, `UseHint` | **tiheä 0/1-taulukko**, 1 bitti/kerroin, `K*256` bittia | 1536 bit (K=6) | EI pakattu - jokainen kerroin oma bittinsa. |
| `h` PAKATTU (allekirjoituksen osa) | `pack_h.sv` | allekirjoituksen viimeinen osa (61 tavua) | FIPS 204:n oma harva esitys: positiolista (OMEGA=55 tavua) + kumulatiiviset offsetit (K=6 tavua) | 8*(OMEGA+K) bit | Symmetrinen `unpack_h`:n kanssa. |
| `ek` (julkinen avain) | `pack_ek.sv` | mika tahansa Verify-kutsuja | pakattu tavujono (`rho\|\|t1_packed`) | 8*(32+K*320) bit | `t1` pakattu 10 bit/kerroin (tiukka, EI keskitetty - t1 on jo ei-negatiivinen `Power2Round`:n oma ylaosa). |
| `dk`/`sk` (yksityinen avain) | `pack_dk.sv` | mika tahansa Sign-kutsuja (paketoituna) TAI suoraan RTL-rekistereina (vaiheistetussa flow'ssa) | pakattu tavujono TAI suorat RTL-rekisterit (`rho`,`K_key`,`s1_flat`,`s2_flat`,`t0_flat`) | vaihtelee | Vaiheistettu `functional_flow` OHITTAA pack_dk/unpack_dk-kierroksen kokonaan - tallentaa `s1`/`s2`/`t0` SUORAAN RTL:n omissa raaka-/Zq-muodoissa (`sk_state.txt`), koska taman KAYTTOTARKOITUS on Sign:n oma sisainen kaytto, ei tallennus/siirto ulkopuolelle. |

## Loydetyt representaatiovirheet (historiallinen kirjaus)

| Pvm | Rajapinta | Virhe | Korjauspaikka |
|---|---|---|---|
| 2026-07-20 (jatko 16) | Sign `z_out_flat` -> `pack_sig` | Zq-muotoinen z syotettiin suoraan keskitetyn arvon olettavaan `pack_z`:aan | Testipenkin/integraatiotason kytkenta (EI `pack_sig.sv`:n sisalla) |
| 2026-07-20 (jatko 19) | KeyGen `t0_flat` -> Sign `sign_hint_core` | Etumerkillinen kaksoiskomplementti-t0 syotettiin suoraan Zq-muotoa olettavaan NTT-putkeen | `stage2_sign_tb.sv`:n oma kytkenta |
| (aiempi, DK5/DK6-tyo) | RTL `verify_top2.sv`:n oma tavujarjestys `$display`-tulosteissa | `%h`-tulostus on MSB-first, mutta `pack_bytes()`-konventio on LSB-first - vaatii tavujarjestyksen kaannon debug-vertailuissa | Debug-skriptien oma `[::-1]`-kaanto Pythonissa |

## Suositus jatkokehitykselle

Kun UUSI rajapinta lisataan (esim. tuleva synteesikohde tai uusi
top-level-wrapper), tarkista AINA tasta taulukosta:
1. Mika on LAHTEEN oma, TODELLINEN esitysmuoto (ei oletettu)?
2. Mika on KOHTEEN olettama esitysmuoto?
3. Jos nama EROAVAT, lisaa EKSPLISIITTINEN, KOMMENTOITU muunnos
   TASAN tahan rajapintaan - ALA oleta etta "sama N-bittinen kentta"
   tarkoittaa samaa asiaa.

Tama dokumentti PAIVITETAAN aina kun uusi representaatioero
loydetaan tai uusi rajapinta lisataan.
