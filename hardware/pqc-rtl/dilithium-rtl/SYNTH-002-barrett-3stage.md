# SYNTH-002: Barrett multiplier 3-stage pipeline exploration

**Status:** Toteutettu, testattu ja mitattu (2026-07-21) - kaikki kolme vaihetta alittavat 60 tason tavoitteen
**Created:** 2026-07-21
**Related:** `SYNTH-001-barrett-pipeline.md`, `SYNTH-TEMPLATE.md`,
`pqc_dilithium_barrett_mulmod_pipe2.sv`

## Vakiorakenne (ks. SYNTH-TEMPLATE.md)

| Kohta | Sisalto |
|---|---|
| **Tavoite** | SYNTH-001:n oma 2-vaiheinen pipeline osoitti epatasapainon (Vaihe1=68, Vaihe2=41 tasoa) - Vaihe 1 kantaa edelleen kaksi peräkkäista kertolaskua (a*b JA product*M_CONST). Tavoitteena jakaa nama KAHTEEN ERI pipeline-vaiheeseen, tasapainottaen kuormaa kolmeen suunnilleen yhta syvaan vaiheeseen. |
| **Lahtotilanne** (MITATTU, SYNTH-001:sta - 2026-07-21) | 2-vaiheinen: `ltp` Vaihe1=**68**, Vaihe2=**41**. 0-vaiheinen (alkuperainen) baseline: `ltp`=**107**, solut=**6517**, FF=**0**. |
| **Muutos** | Jaetaan NYKYINEN Vaihe 1 (product=a*b; q_est=(product*M_CONST)>>K_SHIFT) KAHTEEN OSAAN rekisterirajalla valissa: Uusi Vaihe 1 = product=a*b (VAIN). Uusi Vaihe 2 = product_times_m=product*M_CONST; q_est=yllaolevan ylabitit (lukee Vaihe 1:n rekisteria). Uusi Vaihe 3 = nykyinen Vaihe 2 muuttumattomana (q_est_times_q=q_est*Q; vahennys; normalisointi). `product` taytyy kuljettaa REKISTEROITYNA Vaihe 1:sta Vaihe 3:een asti (kaksi rekisterirajaa ylittaen). |
| **Mittarit** | `ltp` KULLEKIN kolmelle vaiheelle erikseen (eristetyt mittausmoduulit, sama menetelma kuin SYNTH-001). Solu-/FF-maara koko 3-vaiheiselle moduulille. Toiminnallinen testi (100000 satunnaista paria) verrattuna alkuperaiseen kombinatoriseen tulokseen, sama testimetodologia kuin SYNTH-001:n oma `barrett_pipe2_tb.sv`. |
| **Hyvaksymiskriteeri** | (a) Jokainen kolmesta vaiheesta selvasti alle 60 tasoa (kayttajan oma ennuste: ~30-40/vaihe); (b) toiminnallinen testi PASS 100000/100000; (c) solumaaran kasvu pysyy kohtuullisena (verrattuna 2-vaiheisen +2.6% referenssiin); (d) EI viela vaadita NTT-ytimen integraatiota (sama rajaus kuin SYNTH-001:ssa - tama on edelleen ITSENAISEN moduulin tutkimus). |

## Toteutus ja tulokset (2026-07-21) - VALMIS

**Status paivitetty: Open -> Toteutettu, testattu ja mitattu.**

### Toteutettu

- `pqc_dilithium_barrett_mulmod_pipe3.sv`: 3-vaiheinen rekisteroity
  versio, TASMALLEEN kayttajan oman ehdotuksen mukaisella jaolla.
- `barrett_pipe3_tb.sv`: toiminnallinen testi, sama metodologia kuin
  SYNTH-001:ssa (100000 satunnaista paria, vertailu suoraan
  alkuperaiseen kombinatoriseen `pqc_dilithium_barrett_mulmod.sv`:aan).
- Kolme eristettya mittausmoduulia (`..._stage1/2/3_measure.sv`)
  `ltp`-analyysia varten.

### Mitatut tulokset

| Mittari | Baseline (0-vaihe) | 2-vaihe (SYNTH-001) | **3-vaihe (SYNTH-002)** |
|---|---|---|---|
| `ltp` Vaihe 1 | 107 | 68 | **39** |
| `ltp` Vaihe 2 | - | 41 | **33** |
| `ltp` Vaihe 3 | - | - | **41** |
| Solumaara | 6 517 | 6 685 (+2.6%) | **6 699 (+2.8%)** |
| FF-maara | 0 | 93 | **139** (tasmaa odotukseen: product-rekisteri KAHDESTI kuljetettuna 46*2=92b + q_est 24b + result 23b = 139b) |
| Toiminnallinen oikeellisuus | - | PASS 100000/100000 | **PASS 100000/100000** |

### Hyvaksymiskriteerin tarkistus

| Kriteeri | Tulos |
|---|---|
| (a) Jokainen vaihe selvasti alle 60 tasoa | **TAYSIN TAYTETTY**: 39/33/41 - KAIKKI kolme vaihetta alittavat 60:n tavoitteen SELVASTI, ja tasapaino on huomattavasti parempi kuin 2-vaiheisessa (68/41). Kayttajan oma ennuste oli ~35-40/~35-40/~30-35: Vaihe 1 (39) ja Vaihe 2 (33) osuvat ennusteen sisalle (Vaihe 2 jopa hieman ennustettua parempi), mutta Vaihe 3 (41) YLITTAA hieman ennustetun 30-35-haitarin - todennakoisesti koska Vaihe 3 sisaltaa PAITSI vahennyksen MYOS ehdollisen normalisointivertailun (`>= Q`-tarkistus + valinnainen toinen vahennys), mika lisaa hieman syvyytta pelkkaan kertolasku+vahennys-oletukseen verrattuna. Kokonaisuutena ennuste OSUI OIKEAAN SUUNTAAN ja SUURUUSLUOKKAAN, vaikkei tasmalleen jokaisen vaiheen kohdalla. |
| (b) Toiminnallinen testi PASS | **TAYTETTY**: 100000/100000, 0 virhetta. |
| (c) Solumaaran kasvu kohtuullinen | **TAYTETTY**: +2.8% (vs. 2-vaiheisen +2.6%) - lisays YHDESTA lisarekisterista (product kuljetettu KAHDESTI, ei kerran) on marginaalinen. |
| (d) Ei viela vaadita NTT-integraatiota | Sama rajaus kuin SYNTH-001:ssa - EI viela tehty, oma jatkokohta. |

### Johtopaatos

**3-vaiheinen pipeline ON SELVASTI PAREMPI KOMPROMISSI kuin
2-vaiheinen:** kaikki kolme vaihetta alittavat 60 tason tavoitteen
(39/33/41 vs. 2-vaiheisen 68/41), pinta-alakustannus kasvoi VAIN
marginaalisesti (+2.8% vs. +2.6%, eli YHDEN lisarekisterin verran).
TAMA VAHVISTAA kayttajan oman ennakkoarvion SUUNNAN JA SUURUUS-
LUOKAN oikeaksi (epatasapaino 2-vaiheisessa johtui tasan siita etta
Vaihe 1 kantoi KAKSI kertolaskua, ja naiden erottaminen omiin
vaiheisiinsa tasapainotti kuorman) - joskin Vaihe 3:n TARKKA arvo
(41) ylitti hieman ennustetun haitarin (30-35) normalisointivertailun
oman lisasyvyyden vuoksi.

**Suositus:** 3-vaiheinen variantti on PAREMPI valinta kuin
2-vaiheinen, JOS 3 syklin latenssi (2:n sijaan) on hyvaksyttavissa
kutsuvassa kontekstissa (NTT-ydin tekee jo satoja Barrett-kutsuja
per muunnos, joten yksi lisasykli per kutsu on suhteellisen pieni
lisakustannus koko muunnoksen tasolla).

### Seuraava askel (sama kuin SYNTH-001:ssa, EI viela tehty)

NTT-ytimen FSM:n muokkaaminen 3 syklin latenssin huomioimiseksi
JOS 3-vaiheinen pipeline paatetaan ottaa kayttoon tuotannossa -
JAETTU KAHDEKSI erilliseksi tehtavaksi kayttajan oman ehdotuksen
mukaisesti (integraatio ja optimointi eivat saa sekoittua):
- `SYNTH-003A-barrett-ntt-integration.md`: pipe3:n kayttoonotto
  NTT-ytimessa (puhdas integraatiotehtava).
- `SYNTH-003B-normalization-optimization.md`: Vaihe 3:n oman
  (41 tasoa, raskain kolmesta) normalisointilogiikan oma optimointi
  (puhdas suorituskykytehtava, EI liity integraatioon).
