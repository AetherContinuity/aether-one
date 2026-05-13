from dataclasses import dataclass
from typing import Dict, Any

from .trustcore_adapter import TrustCoreNative

# Load deterministic C core (TrustCore v1.0)
_trustcore = TrustCoreNative()


@dataclass
class KRIState:
    R: float  # Resilience
    S: float  # Stress
    E: float  # Exposure
    constructive: bool  # LR-D
    deltas: Dict[str, float]
    kri: float  # TrustCore v1.0 KRI output


def compute_kri(sensor_state: Dict[str, Any]) -> KRIState:
    """Compute R/S/E from sensors (demo mapping), then evaluate KRI + LR-D via TrustCore v1.0 C core."""

    voc = float(sensor_state.get("voc_ppb", 0.0))
    geiger = float(sensor_state.get("geiger_cpm", 0.0))
    obstacles = int(sensor_state.get("lidar_obstacles", 0))

    # Demo sensor->state mapping (keep in Python for now)
    S = min(1.0, (voc / 500.0) + (geiger / 100.0))
    E = min(1.0, 0.2 * obstacles)
    R = max(0.0, 1.0 - 0.5 * (S + E))

    kri_value = _trustcore.kri(R, S, E)
    dis = _trustcore.dissonance(R, S, E)

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
