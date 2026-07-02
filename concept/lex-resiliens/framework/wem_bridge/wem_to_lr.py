#!/usr/bin/env python3
"""
wem_to_lr.py

Muuntaa WEM:n §12-mittauspisteet Lex Resiliens -agentin R/S-pisteiksi.

Perustuu ACI-INSTRUMENT-v2.html:n §12-osioon (todennettu suoraan lähdekoodista,
ei oletettu): DS 60 (SE1->FI siirto), DS 24 (suunniteltu/dynaaminen NTC),
DS 336 (shortage status 0-3), DS 177 (taajuus, porrastetut kynnykset).

MUUTOKSET AIEMPAAN VERSIOON:
1. se1_capacity_mw ei ole enää vakio (2300 MW). Se on pakollinen per-snapshot
   syote DS 24:sta, koska Fingrid/Svenska kraftnat saatavat siirtokapasiteettia
   dynaamisesti flow-based-menetelmalla (NTC:sta luovuttu 29.10.2024/2025/2026).
   WEM:n oma koodi kayttaa kovakoodattua ntcApprox=2300 - tama on WEM:n OMA
   dokumentoitu puute (rivi 728), ei toistettava tassa.
2. internal_capacity_mw on optional. Jos puuttuu, R lasketaan pelkasta
   SE1-marginaalista eika sisaiselle siirrolle arvata nimittajaa.
3. Taajuuspisteytys kayttaa WEM:n omia porrastettuja kynnyksia
   (0.1/0.2/0.5 Hz), ei lineaarista liukua.
4. battery_soc_percent POISTETTU. WEM ei hae akkudataa reaaliajassa §12:ssa
   (DS 398-399 esiintyy vain ECI:n staattisessa rakennekuvassa). E-akseli
   jaa pois - tama on kaksiakselinen (R,S) malli kolmen sijaan, koska
   kolmatta akselia ei voi perustella olemassa olevalla datalla.

VALIDOINTIRAJOITE (kirjattu eksplisiittisesti):
Kayttajan oman tiedon mukaan varsinaista kriisia ei ole ollut lahivuosina.
Tama tarkoittaa etta shortage_status on todennakoisesti pysynyt 0:ssa koko
havaintojakson. Watch/Warning/Emergency-kynnyksia (1/2/3) EI OLE TESTATTU
oikeaa dataa vasten. Lapaisy tyhjaa dataa vasten ei ole validointi - se on
puuttuvan negatiivin puuttuminen. Talla moduulilla ei voi vaittaa etta S:n
kriisikynnykset toimivat, vain etta niita ei ole kumottu.
"""

from __future__ import annotations
from dataclasses import dataclass
from typing import Optional


def clamp(v: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return max(lo, min(hi, v))


@dataclass
class WemSnapshot:
    """Yhden ajanhetken mittauspiste. Kentat vastaavat WEM §12:n
    todennettua DS-karttaa (ei oletettua)."""
    region_id: str

    # DS 60 - SE1->FI toteutunut siirto (MW, itseisarvo kayttokelpoinen)
    se1_flow_mw: float

    # DS 24 - suunniteltu/dynaaminen NTC-kapasiteetti (MW). PAKOLLINEN.
    # Ei vakio - haettava per snapshot, koska kapasiteetti on flow-based
    # ja Svenska kraftnat/Fingrid saatavat sita tilanteen mukaan.
    se1_capacity_mw: float

    # DS 30 - sisainen pohjoinen -> etela -siirto. Optional pari.
    internal_flow_mw: Optional[float] = None
    internal_capacity_mw: Optional[float] = None

    # DS 336 - shortage status, kokonaisluku 0-3 (0=normaali,3=emergency)
    shortage_status: int = 0

    # DS 177 - taajuus, Hz
    frequency_hz: float = 50.00

    data_fresh: bool = True


# --- Vakiot, nimettyina ja perusteltuina, ei piilotettuja ------------------
SE1_WEIGHT_ALONE = 1.0        # kun internal-dataa ei ole
SE1_WEIGHT_WITH_INTERNAL = 0.6
INTERNAL_WEIGHT = 0.4

# Taajuuskynnykset suoraan WEM §12:sta (rivi 2974), ei omaa keksintoa:
# poikkeama < 0.1 Hz = Stable, < 0.2 = Watch, < 0.5 = Warning, >= 0.5 = Critical
FREQ_THRESHOLDS_HZ = [0.10, 0.20, 0.50]

SHORTAGE_SOCIAL_WEIGHT = 0.5
FREQ_SOCIAL_WEIGHT = 0.5


def _transfer_margin(flow_mw: float, capacity_mw: float) -> float:
    if capacity_mw <= 0:
        return 0.0
    return clamp(1.0 - abs(flow_mw) / capacity_mw)


def _frequency_score(frequency_hz: float) -> float:
    """Porrastettu, ei lineaarinen. Palauttaa 1.0/0.66/0.33/0.0 sen mukaan
    mihin WEM:n omista neljasta luokasta poikkeama osuu."""
    dev = abs(frequency_hz - 50.00)
    if dev < FREQ_THRESHOLDS_HZ[0]:
        return 1.0   # Stable
    if dev < FREQ_THRESHOLDS_HZ[1]:
        return 0.66  # Watch
    if dev < FREQ_THRESHOLDS_HZ[2]:
        return 0.33  # Warning
    return 0.0       # Critical


def compute_R(snap: WemSnapshot) -> float:
    se1_margin = _transfer_margin(snap.se1_flow_mw, snap.se1_capacity_mw)
    if snap.internal_flow_mw is not None and snap.internal_capacity_mw is not None:
        internal_margin = _transfer_margin(snap.internal_flow_mw, snap.internal_capacity_mw)
        return clamp(SE1_WEIGHT_WITH_INTERNAL * se1_margin + INTERNAL_WEIGHT * internal_margin)
    return clamp(SE1_WEIGHT_ALONE * se1_margin)


def compute_S(snap: WemSnapshot) -> float:
    if not (0 <= snap.shortage_status <= 3):
        raise ValueError(f"shortage_status oltava 0-3, saatiin {snap.shortage_status}")
    shortage_score = clamp(1.0 - snap.shortage_status / 3.0)
    freq_score = _frequency_score(snap.frequency_hz)
    return clamp(SHORTAGE_SOCIAL_WEIGHT * shortage_score + FREQ_SOCIAL_WEIGHT * freq_score)


def snapshot_to_agent(snap: WemSnapshot) -> dict:
    """HUOM: ei E-arvoa. Kutsuvan koodin (relay) pitaa joko hyvaksya
    kaksiakselinen agentti tai taytta E kiintealla neutraalilla ulkopuolelta
    - tama moduuli ei keksi kolmatta akselia jolle ei ole datalahdetta."""
    return {
        "name": snap.region_id,
        "R": round(compute_R(snap), 4),
        "S": round(compute_S(snap), 4),
        "irs_ok": 1 if snap.data_fresh else 0,
        "rap_ok": 1,
    }
