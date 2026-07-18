# M5-DILITHIUM-001 DK1: 32-bittinen NTT-ydin

**Paivamaara:** 2026-07-19
**Tila:** Ensimmainen rakennuspalikka (Barrett-kertolaskureduktio) VALMIS.

## Arkkitehtuurivalinta: Barrett Montgomery-domainin sijaan

**Peruste:** `dilithium-golden/M5_DILITHIUM_001_PLAN.md` (osio 4)
dokumentoi etta rvv-dilithium-ohjelmistototeutus loysi "vaaran
Montgomery-etumerkkikonvention" KAHDESTI eri kohdissa. Barrett-
reduktio valttaa TAMAN kokonaan: arvot pysyvat koko ajan normaali-
alueella (0..Q-1), ei tarvetta Montgomery-domainiin/-domainista
muuntamiselle eika sen omalle etumerkkikonvention sekaannukselle.

Tama on TIETOINEN, dokumentoitu arkkitehtuurivalinta - EI sama
lahestymistapa kuin ohjelmistoreferenssissa, koska FPGA-DSP-lohkot
mahdollistavat suoran 23x23-bittisen kertolaskun ilman Montgomeryn
omaa optimointitarvetta (joka oli alun perin motivoitu OHJELMISTON
jakolaskun kalleudesta - RTL:ssa modulo-operaatio VOIDAAN toteuttaa
suoraan Barrett-piirilla ilman vastaavaa kustannusta).

## Barrett-parametrit (Q=8380417)

- k=46 (siirtomaara), m=floor(2^46/Q)=8396807
- Vahvistettu Pythonilla 100000 satunnaisella parilla ENNEN RTL-
  tyota: 0 virhetta.

## Toteutus ja testitulos

`pqc_dilithium_barrett_mulmod.sv` - taysin kombinatorinen (sama
periaate kuin `pqc_compress.sv`, `pqc_multiplyntts.sv` jne).

```
PASS: Barrett mulmod tasmaa taydellisesti kaikille 506 testitapaukselle
```

506 testitapausta = 6 reunatapausta (0,0 / Q-1,Q-1 / jne) + 500
satunnaista paria, verrattu SUORAAN Pythonin `(a*b)%Q`:hun.

## Seuraava askel

Yksittainen Cooley-Tukey-butterfly (t=zeta*b mod Q; out_a=(a+t)%Q;
out_b=(a-t)%Q, HUOM out_b:n oma modulo-alivuoto vaatii oman
kasittelynsa koska a-t voi olla negatiivinen) - testattava YHTA
butterfly-operaatiota vasten `dilithium-py`:n omasta `to_ntt()`-
metodista ENNEN koko 256-kertoimisen NTT-skeduloinnin rakentamista.
