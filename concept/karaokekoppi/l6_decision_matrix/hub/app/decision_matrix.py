from __future__ import annotations

"""KaraokeKoppi™ L6 Decision Matrix

Deterministinen, läpinäkyvä "what-if" -taulukko.
Ei ennusta verkkoa; antaa muokattavat vaikutusarviot (deltat).
"""

from dataclasses import dataclass, asdict
from typing import Any, Dict, List, Literal, Optional

LockLevel = Literal["OK", "WEAK", "CRITICAL"]

_LOCK_ORDER: List[LockLevel] = ["OK", "WEAK", "CRITICAL"]
_LOCK_INDEX = {k: i for i, k in enumerate(_LOCK_ORDER)}


def clamp(v: float, lo: float, hi: float) -> float:
    return lo if v < lo else hi if v > hi else v


def nudge_lock(level: LockLevel, step: int) -> LockLevel:
    """step>0 parantaa (kohti OK), step<0 huonontaa."""
    idx = _LOCK_INDEX.get(level, 1)
    new_idx = idx - step
    new_idx = max(0, min(len(_LOCK_ORDER) - 1, new_idx))
    return _LOCK_ORDER[new_idx]


@dataclass(frozen=True)
class ActionEffect:
    delta_index: float
    reserve: int = 0
    inertia: int = 0
    time: int = 0
    governance: int = 0
    political_cost: int = 0  # 0..3
    economic_cost: int = 0   # 0..3
    rationale: str = ""


@dataclass(frozen=True)
class Action:
    id: str
    title: str
    description: str
    effect: ActionEffect
    tags: List[str]


def get_actions() -> List[Action]:
    """Oletuskatalogi. Muokkaa arvoja audit-datan perusteella."""
    return [
        Action(
            id="mFRR_DEMAND_RESPONSE_300",
            title="Kysyntäjousto (mFRR) 300 MW",
            description="Aktivoi nopea kysyntäjousto. Parantaa reservimarginaalia.",
            effect=ActionEffect(
                delta_index=+0.08,
                reserve=+1,
                political_cost=1,
                economic_cost=1,
                rationale="Nopea jousto nostaa käytettävää säätövaraa ja palauttaa marginaalia.",
            ),
            tags=["reserve", "fast"],
        ),
        Action(
            id="PEAKING_UNITS_ON",
            title="Huippuyksiköt päälle",
            description="Käynnistä tehoreservi/huippuyksiköt (kallis mutta tehokas).",
            effect=ActionEffect(
                delta_index=+0.12,
                reserve=+1,
                inertia=+1,
                political_cost=1,
                economic_cost=2,
                rationale="Lisäkapasiteetti + pyörivä massa parantaa taajuusvakautta.",
            ),
            tags=["reserve", "inertia"],
        ),
        Action(
            id="LEVEL2_PUBLIC_COMMS",
            title='Viestintä: "Taso 2"',
            description="Ennakoiva sidosryhmä- ja yleisöviesti. Vähentää viivettä.",
            effect=ActionEffect(
                delta_index=+0.02,
                governance=+1,
                political_cost=1,
                economic_cost=0,
                rationale="Selkeä tilannekuva tukee koordinoitua reagointia.",
            ),
            tags=["governance", "comms"],
        ),
        Action(
            id="CONTROLLED_LOAD_SHED_200",
            title="Hallitut kiertävät katkot 200 MW",
            description="Kova hätätoimi: kuorman lasku estää kaskadia.",
            effect=ActionEffect(
                delta_index=+0.16,
                reserve=+1,
                governance=+1,
                political_cost=3,
                economic_cost=3,
                rationale="Kuorman lasku parantaa marginaalia nopeasti, jos ollaan lähellä rajaa.",
            ),
            tags=["emergency", "load"],
        ),
        Action(
            id="IMPORT_MAXIMIZATION",
            title="Importin maksimointi",
            description="Optimoi rajasiirrot ja kaupallinen importti (jos kapasiteettia).",
            effect=ActionEffect(
                delta_index=+0.05,
                economic_cost=1,
                rationale="Lyhytaikainen helpotus, jos naapurit kykenevät toimittamaan.",
            ),
            tags=["import"],
        ),
        Action(
            id="DO_NOTHING",
            title="Ei toimia (seuranta)",
            description="Ei muutoksia. Sopii vain, jos lukot eivät kiristy.",
            effect=ActionEffect(
                delta_index=-0.03,
                rationale="Ajan kuluessa marginaali usein heikkenee, jos olosuhteet ovat jo huonot.",
            ),
            tags=["monitor"],
        ),
    ]


def action_by_id(action_id: str) -> Optional[Action]:
    for a in get_actions():
        if a.id == action_id:
            return a
    return None


def to_public_dict(action: Action) -> Dict[str, Any]:
    d = asdict(action)
    d["effect"] = asdict(action.effect)
    return d
