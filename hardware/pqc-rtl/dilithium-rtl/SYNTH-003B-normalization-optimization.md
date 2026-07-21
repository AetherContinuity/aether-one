# SYNTH-003B: Barrett normalization stage optimization

**Status:** Open
**Created:** 2026-07-21
**Related:** `SYNTH-002-barrett-3stage.md`, `pqc_dilithium_barrett_pipe3_stage3_measure.sv`

**Kayttajan oma rajaus:** tama on PUHDAS optimointitehtava, EI
integraatiotehtava. NTT-ytimen oma kaytto (`pipe3`:n kayttoonotto
tuotannossa) on ERIKSEEN `SYNTH-003A-barrett-ntt-integration.md`:ssa.
Naita EI sekoiteta samaan tehtavaan.

## Vakiorakenne (ks. SYNTH-TEMPLATE.md)

| Kohta | Sisalto |
|---|---|
| **Tavoite** | SYNTH-002 osoitti etta Vaihe 3 (q_est*Q + vahennys + normalisointi) ON nyt RASKAIN kolmesta vaiheesta (41 tasoa vs. Vaihe1:n 39 ja Vaihe2:n 33) - vaikka SISALTAA vain YHDEN kertolaskun (kevyempi kuin Vaihe 1:n yksi JA Vaihe 2:n yksi). Tama viittaa siihen etta normalisointi-/vahennyslogiikka (ehdollinen `>= Q`-vertailu + valinnainen toinen vahennys) ITSESSAAN on suhteellisen kallis. Tavoitteena tutkia VOIKO tata logiikkaa yksinkertaistaa tai nopeuttaa SUORAAN, EI lisaamalla enaa pipeline-vaiheita. |
| **Lahtotilanne** (MITATTU, SYNTH-002:sta - 2026-07-21) | Vaihe 3:n oma `ltp`: **41** tasoa (`pqc_dilithium_barrett_pipe3_stage3_measure.sv`). Sisalto: `q_est_times_q = q_est*Q` (24x23-bittinen kertolasku) + `r_wide = product - q_est_times_q` (47-bittinen vahennys) + ehdollinen `(r_wide >= Q) ? (r_wide-Q) : r_wide[CW-1:0]` (47-bittinen vertailu + valinnainen 47-bittinen vahennys + leikkaus). |
| **Muutos** | TUTKITTAVIA vaihtoehtoja (paatetaan toteutusvaiheessa mika/mitka kokeillaan): (1) Comparator-rakenteen uudelleensuunnittelu (esim. etumerkkibitin kayttö suoraan `>= Q`-tarkistuksen sijaan, jos vahennyksen oma etumerkki voidaan paatella halvemmalla). (2) Carry-save- tai carry-lookahead-rakenteen eksplisiittinen kayttö 47-bittiselle vahennykselle geneerisen `-`-operaattorin sijaan. (3) Vaihtoehtoinen modulo-Q-normalisointimenetelma (esim. jos Barrett-vakion `M_CONST`/`K_SHIFT`-valinnalla VOITAISIIN taata etta VAIN yksi, ei-ehdollinen vahennys riittaa - vaatisi Barrett-parametrien oman uudelleentarkistuksen, EI vain RTL-rakenteen). |
| **Mittarit** | `ltp` Vaihe 3:n omalle, MUUTETULLE versiolle (verrattuna 41:n baseline-arvoon). Solu-/FF-maara (odotetaan pysyvan suunnilleen ennallaan tai jopa PIENENEVAN, jos loydetaan tehokkaampi rakenne). Toiminnallinen testi (sama 100000-parin metodologia kuin SYNTH-001/002). |
| **Hyvaksymiskriteeri** | (a) Vaihe 3:n oma `ltp` PIENENEE mitattavasti alle 41:n (tavoite: samalle tasolle kuin Vaihe 2:n 33, jotta KAIKKI kolme vaihetta olisivat suunnilleen yhta syvia); (b) toiminnallinen testi PASS 100000/100000 muuttumattomana; (c) solumaaran mahdollinen kasvu (JOS rakenne monimutkaistuu esim. carry-lookahead:in vuoksi) pysyy kohtuullisena suhteessa saatuun `ltp`-hyotyyn. |

## Tausta

SYNTH-002:n oma, yllattava havainto: Vaihe 3 (41 tasoa) ON
raskaampi kuin Vaihe 1 (39) VAIKKA Vaihe 1 sisaltaa TASAN yhta
suuren (23x23-bittisen) kertolaskun kuin Vaihe 3:n oma 24x23-
bittinen kertolasku - eron TAYTYY siis tulla NIMENOMAAN vahennys-
/normalisointilogiikasta (`r_wide = product - q_est_times_q` +
ehdollinen `>= Q`-korjaus), EIKA itse kertolaskusta.

Tama on kayttajan oma, tarkka havainto joka nostaa esiin
KONKREETTISEN, aiemmin piilossa olleen optimointikohteen - ilman
kolmen vaiheen erillista `ltp`-mittausta tama epasuhta ei olisi
tullut nakyviin (koko moduulin YHTEINEN `ltp` [107 tai kokonais-
pipeline] EI OLISI paljastanut ETTA nimenomaan normalisointilogiikka,
EI kertolasku, on suhteellisesti raskain osa).

## Rajaukset (EI kuulu tahan tehtavaan)

- NTT-ytimen oma integraatio (FSM-muutokset) - ks. `SYNTH-003A-
  barrett-ntt-integration.md`.
- Barrett-parametrien (`M_CONST`, `K_SHIFT`) oma matemaattinen
  uudelleenjohtaminen EI KUULU tahan PERUSTASON tehtavaan, ELLEI
  vaihtoehto (3) ylla osoittaudu lupaavaksi ja vaadi sita - siina
  tapauksessa TAMA olisi oma, viela kapeampi jatkotehtavansa
  (Barrett-vakioiden matemaattinen todentaminen vaatisi SAMAN
  100000-parin-testimetodologian, mutta myos huolellisen matemaat-
  tisen perustelun, EI vain RTL-kokeilua).
