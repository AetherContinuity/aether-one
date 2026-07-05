"""
Decision Matrix - TÄYDELLINEN TOIMENPIDE-KATALOGI

Kaikki käytettävissä olevat toimenpiteet Suomen sähköjärjestelmän
resilienssikrii:n hallintaan.
"""

from dataclasses import dataclass
from typing import Dict, List, Literal

@dataclass
class ActionEffect:
    lock_name: str
    impact: float
    effect_type: Literal["direct", "indirect", "delayed"]
    duration_minutes: int
    activation_delay_minutes: int = 0

@dataclass
class Action:
    id: str
    name: str
    description: str
    effects: List[ActionEffect]
    resources_required: Dict[str, float]
    political_risk: Literal["low", "medium", "high"]
    technical_risk: Literal["low", "medium", "high"]
    public_acceptance_risk: Literal["low", "medium", "high"]
    prerequisites: List[str]
    min_activation_time_minutes: int
    typical_activation_time_minutes: int
    max_duration_hours: int

ACTIONS = [
    # KYSYNTÄJOUSTO
    Action(
        id="demand_response_residential",
        name="Kysyntäjousto - Kotitaloudet",
        description="Sähkölämmityksen lyhytaikainen vähennys kotitalouksissa",
        effects=[
            ActionEffect("Reserve", 0.15, "direct", 120, 15),
            ActionEffect("Governance", -0.05, "indirect", 120, 0)
        ],
        resources_required={"budget_eur": 5000, "personnel": 2},
        political_risk="low",
        technical_risk="low",
        public_acceptance_risk="medium",
        prerequisites=[],
        min_activation_time_minutes=10,
        typical_activation_time_minutes=15,
        max_duration_hours=4
    ),
    
    Action(
        id="demand_response_industrial",
        name="Kysyntäjousto - Teollisuus",
        description="Teollisuuden energiaintensiivisten prosessien keskeytys",
        effects=[
            ActionEffect("Reserve", 0.25, "direct", 180, 30),
            ActionEffect("Governance", -0.10, "indirect", 180, 0)
        ],
        resources_required={"budget_eur": 50000, "personnel": 5},
        political_risk="medium",
        technical_risk="low",
        public_acceptance_risk="medium",
        prerequisites=[],
        min_activation_time_minutes=20,
        typical_activation_time_minutes=30,
        max_duration_hours=6
    ),
    
    # TUOTANNON LISÄYS
    Action(
        id="reserve_power_activation",
        name="Varavoiman käynnistys",
        description="Reservissä olevien voimalaitosten käynnistäminen",
        effects=[
            ActionEffect("Reserve", 0.30, "direct", 360, 45),
            ActionEffect("Time", 0.05, "indirect", 360, 60),
            ActionEffect("Governance", -0.08, "delayed", 1440, 120)
        ],
        resources_required={"budget_eur": 200000, "personnel": 10, "fuel_reserve": 0.05},
        political_risk="medium",
        technical_risk="low",
        public_acceptance_risk="low",
        prerequisites=[],
        min_activation_time_minutes=30,
        typical_activation_time_minutes=45,
        max_duration_hours=24
    ),
    
    # TUONTI
    Action(
        id="import_increase_sweden",
        name="Tuonti Ruotsista (lisäys)",
        description="Siirtokapasiteetin maksimointi Ruotsista",
        effects=[
            ActionEffect("Reserve", 0.12, "direct", 240, 10),
            ActionEffect("Governance", -0.12, "indirect", 240, 0)
        ],
        resources_required={"budget_eur": 100000, "political_capital": 0.1},
        political_risk="high",
        technical_risk="medium",
        public_acceptance_risk="low",
        prerequisites=[],
        min_activation_time_minutes=5,
        typical_activation_time_minutes=10,
        max_duration_hours=12
    ),
    
    Action(
        id="import_increase_norway",
        name="Tuonti Norjasta (lisäys)",
        description="Siirtokapasiteetin maksimointi Norjasta",
        effects=[
            ActionEffect("Reserve", 0.10, "direct", 240, 10),
            ActionEffect("Governance", -0.10, "indirect", 240, 0)
        ],
        resources_required={"budget_eur": 90000, "political_capital": 0.1},
        political_risk="medium",
        technical_risk="medium",
        public_acceptance_risk="low",
        prerequisites=[],
        min_activation_time_minutes=5,
        typical_activation_time_minutes=10,
        max_duration_hours=12
    ),
    
    # KULUTUKSEN RAJOITUS (PAKKO)
    Action(
        id="rolling_blackouts_targeted",
        name="Kiertävät katkot (kohdistetut)",
        description="Lyhytaikaiset sähkökatkot valituilla alueilla",
        effects=[
            ActionEffect("Reserve", 0.40, "direct", 120, 30),
            ActionEffect("Governance", -0.35, "delayed", 10080, 60),
            ActionEffect("Time", 0.10, "indirect", 120, 30)
        ],
        resources_required={"budget_eur": 500000, "personnel": 50, "political_capital": 0.5},
        political_risk="high",
        technical_risk="medium",
        public_acceptance_risk="high",
        prerequisites=["public_communication_emergency"],
        min_activation_time_minutes=20,
        typical_activation_time_minutes=30,
        max_duration_hours=4
    ),
    
    # VIESTINTÄ
    Action(
        id="public_communication_emergency",
        name="Viestintä - Hätätilanne",
        description="Julkinen viestintä: pyyntö vapaaehtoiseen kulutuksen vähentämiseen",
        effects=[
            ActionEffect("Reserve", 0.05, "indirect", 180, 30),
            ActionEffect("Governance", 0.08, "direct", 1440, 5)
        ],
        resources_required={"budget_eur": 10000, "personnel": 3},
        political_risk="low",
        technical_risk="low",
        public_acceptance_risk="low",
        prerequisites=[],
        min_activation_time_minutes=5,
        typical_activation_time_minutes=10,
        max_duration_hours=24
    ),
    
    Action(
        id="public_communication_preparedness",
        name="Viestintä - Varautuminen",
        description="Ennakkoviestintä sääennusteen perusteella",
        effects=[
            ActionEffect("Governance", 0.05, "direct", 2880, 0)
        ],
        resources_required={"budget_eur": 5000, "personnel": 2},
        political_risk="low",
        technical_risk="low",
        public_acceptance_risk="low",
        prerequisites=[],
        min_activation_time_minutes=5,
        typical_activation_time_minutes=10,
        max_duration_hours=48
    ),
]

def get_action_by_id(action_id: str) -> Action:
    for action in ACTIONS:
        if action.id == action_id:
            return action
    raise ValueError(f"Action not found: {action_id}")
