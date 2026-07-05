from dataclasses import dataclass
from typing import Dict, Any

# HUOM (2026-07-05): tama moduuli tuotti aiemmin
# "from .trustcore_adapter import TrustCoreNative", joka kutsui
# ctypes.CDLL:aa polkuun trustcore_native/libtrustcore.so JOTA EI OLE
# KOSKAAN OLLUT REPOSSA. Tama tarkoittaa etta pi5_edge_node ei ole
# koskaan pystynyt kaynnistymaan onnistuneesti - import olisi
# kaatunut valittomasti. Loytyi kahden ulkopuolisen LLM-arvion
# riippumattomasta havainnosta, vahvistettu suoraan koodista.
#
# Alkuperaista tc_calculate_kri/tc_calculate_dissonance -kaavaa ei ole
# koskaan spesifioitu missaan Python-tasolla - se oli kokonaan C:n
# vastuulla. Alla oleva ei ole "palautettu" alkuperainen logiikka,
# vaan uusi, tarkoituksella yksinkertainen korvaaja joka mahdollistaa
# ajon. Korvaa oikealla spesifikaatiolla jos/kun sellainen maaritellaan.

_previous_state: Dict[str, float] = {"R": None, "S": None, "E": None}


def _kri_placeholder(R: float, S: float, E: float) -> float:
    """Yksinkertainen, dokumentoitu placeholder-KRI: kasvaa stressin ja
    altistuksen mukana, laskee resilienssin mukana. EI alkuperainen
    C-kaava (sellaista ei ole koskaan ollut olemassa Python-tasolla)."""
    return max(0.0, min(1.0, (S + E - R + 1.0) / 2.0))


def _dissonance_placeholder(R: float, S: float, E: float) -> Dict[str, Any]:
    """Placeholder-dissonanssilaskenta: seuraa R/S/E:n muutosta edellisesta
    kutsusta (moduulitason tila). 'constructive' = resilienssi ei laske
    kun stressi/altistus nousee."""
    global _previous_state
    prev = _previous_state
    if prev["R"] is None:
        delta_R = delta_S = delta_E = 0.0
    else:
        delta_R = R - prev["R"]
        delta_S = S - prev["S"]
        delta_E = E - prev["E"]
    _previous_state = {"R": R, "S": S, "E": E}

    constructive = True
    if (delta_S > 0 or delta_E > 0) and delta_R < 0:
        constructive = False

    return {
        "constructive": constructive,
        "delta_R": delta_R,
        "delta_S": delta_S,
        "delta_E": delta_E,
    }


@dataclass
class KRIState:
    R: float  # Resilience
    S: float  # Stress
    E: float  # Exposure
    constructive: bool  # LR-D
    deltas: Dict[str, float]
    kri: float  # KRI-arvo (placeholder-kaavalla, ks. yllaoleva huomautus)


def compute_kri(sensor_state: Dict[str, Any]) -> KRIState:
    """Compute R/S/E from sensors (demo mapping), then evaluate KRI + LR-D
    placeholder-kaavoilla (ks. moduulin alkuosan huomautus)."""

    voc = float(sensor_state.get("voc_ppb", 0.0))
    geiger = float(sensor_state.get("geiger_cpm", 0.0))
    obstacles = int(sensor_state.get("lidar_obstacles", 0))

    # Demo sensor->state mapping (keep in Python for now)
    S = min(1.0, (voc / 500.0) + (geiger / 100.0))
    E = min(1.0, 0.2 * obstacles)
    R = max(0.0, 1.0 - 0.5 * (S + E))

    kri_value = _kri_placeholder(R, S, E)
    dis = _dissonance_placeholder(R, S, E)

    return KRIState(
        R=R,
        S=S,
        E=E,
        constructive=dis["constructive"],
        deltas={
            "delta_R": dis["delta_R"],
            "delta_S": dis["delta_S"],
            "delta_E": dis["delta_E"],
        },
        kri=kri_value,
    )
