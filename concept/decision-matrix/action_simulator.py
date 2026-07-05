"""
Action Simulator - "Mitä jos...?" -logiikka

Simuloi yhden tai useamman toimenpiteen vaikutukset
nykyiseen tilannekuvaan.
"""

from typing import List, Dict
from dataclasses import dataclass
import copy


@dataclass
class SimulationResult:
    """Simulaation tulos"""
    
    # Alkutilanne
    initial_state: Dict[str, any]
    
    # Käytetyt toimenpiteet
    actions_applied: List[str]  # Action ID:t
    
    # Lopputilanne
    final_state: Dict[str, any]
    
    # Muutokset
    lock_changes: Dict[str, float]  # Esim: {"Reserve": +0.15, "Time": +0.05}
    index_change: float  # Esim: +0.12
    
    # Aika
    time_to_full_effect_minutes: int  # Kuinka kauan kestää että kaikki vaikutukset aktivoituvat
    
    # Riskit
    combined_risks: Dict[str, str]  # {"political": "medium", "technical": "low", ...}
    
    # Kustannukset
    total_cost_eur: float
    total_personnel: int


class ActionSimulator:
    """Simuloi toimenpiteiden vaikutuksia"""
    
    def __init__(self, actions_catalog: List):
        """
        Args:
            actions_catalog: Lista Action-objekteja (decision_matrix.ACTIONS)
        """
        self.actions = {a.id: a for a in actions_catalog}
    
    def simulate(
        self, 
        current_snapshot: Dict,
        action_ids: List[str]
    ) -> SimulationResult:
        """
        Simuloi mitä tapahtuu jos annetut toimenpiteet toteutetaan.
        
        Args:
            current_snapshot: Nykyinen SSA snapshot
                {
                    "locks": {"Reserve": "WEAK", "Time": "CRITICAL", ...},
                    "signals": {...},
                    "resilience_index": 0.67
                }
            action_ids: Lista toimenpide-ID:itä jotka "toteutetaan"
        
        Returns:
            SimulationResult joka sisältää lopputilanteen
        """
        
        # Validoi toimenpiteet
        for aid in action_ids:
            if aid not in self.actions:
                raise ValueError(f"Unknown action: {aid}")
        
        # Tarkista esiehdot (prerequisites)
        self._validate_prerequisites(action_ids)
        
        # Kopioi alkutilanne
        initial_locks = self._lock_status_to_numeric(current_snapshot["locks"])
        final_locks = copy.deepcopy(initial_locks)
        
        # Laske kaikki vaikutukset
        lock_changes = {lock: 0.0 for lock in initial_locks.keys()}
        max_activation_time = 0
        
        for aid in action_ids:
            action = self.actions[aid]
            
            for effect in action.effects:
                # Jos lukko ei ole snapshotissa, lisää se
                if effect.lock_name not in lock_changes:
                    lock_changes[effect.lock_name] = 0.0
                
                # Summaa vaikutus
                lock_changes[effect.lock_name] += effect.impact
                
                # Päivitä maksimiaktivaatioaika
                total_time = effect.activation_delay_minutes + (effect.duration_minutes // 2)
                max_activation_time = max(max_activation_time, total_time)
        
        # Päivitä lukkojen arvot
        for lock_name, change in lock_changes.items():
            if lock_name in final_locks:
                final_locks[lock_name] = max(0.0, min(1.0, final_locks[lock_name] + change))
        
        # Laske uusi resilience index
        initial_index = current_snapshot.get("resilience_index", 0.0)
        final_index = sum(final_locks.values()) / len(final_locks) if final_locks else 0.0
        index_change = final_index - initial_index
        
        # Yhdistä riskit
        combined_risks = self._combine_risks(action_ids)
        
        # Laske kokonaiskustannukset
        total_cost = sum(
            self.actions[aid].resources_required.get("budget_eur", 0)
            for aid in action_ids
        )
        total_personnel = sum(
            self.actions[aid].resources_required.get("personnel", 0)
            for aid in action_ids
        )
        
        # Muodosta lopputilanne
        final_state = copy.deepcopy(current_snapshot)
        final_state["locks"] = self._numeric_to_lock_status(final_locks)
        final_state["resilience_index"] = final_index
        
        return SimulationResult(
            initial_state=current_snapshot,
            actions_applied=action_ids,
            final_state=final_state,
            lock_changes=lock_changes,
            index_change=index_change,
            time_to_full_effect_minutes=max_activation_time,
            combined_risks=combined_risks,
            total_cost_eur=total_cost,
            total_personnel=total_personnel
        )
    
    def _validate_prerequisites(self, action_ids: List[str]):
        """Tarkista että kaikki esiehdot täyttyvät"""
        for aid in action_ids:
            action = self.actions[aid]
            for prereq in action.prerequisites:
                if prereq not in action_ids:
                    raise ValueError(
                        f"Action '{aid}' requires '{prereq}' to be executed first"
                    )
    
    def _lock_status_to_numeric(self, locks: Dict[str, str]) -> Dict[str, float]:
        """Muunna lukkojen tila (OK/WEAK/CRITICAL) numeeriseksi (0..1)"""
        mapping = {
            "OK": 1.0,
            "WEAK": 0.7,
            "CRITICAL": 0.3,
            "UNKNOWN": 0.5
        }
        return {
            name: mapping.get(status, 0.5)
            for name, status in locks.items()
        }
    
    def _numeric_to_lock_status(self, locks: Dict[str, float]) -> Dict[str, str]:
        """Muunna numeeriset arvot takaisin tilaksi"""
        result = {}
        for name, value in locks.items():
            if value >= 0.85:
                result[name] = "OK"
            elif value >= 0.5:
                result[name] = "WEAK"
            else:
                result[name] = "CRITICAL"
        return result
    
    def _combine_risks(self, action_ids: List[str]) -> Dict[str, str]:
        """Yhdistä usean toimenpiteen riskit (pahin voittaa)"""
        risk_levels = ["low", "medium", "high"]
        
        max_political = "low"
        max_technical = "low"
        max_public = "low"
        
        for aid in action_ids:
            action = self.actions[aid]
            
            if risk_levels.index(action.political_risk) > risk_levels.index(max_political):
                max_political = action.political_risk
            
            if risk_levels.index(action.technical_risk) > risk_levels.index(max_technical):
                max_technical = action.technical_risk
            
            if risk_levels.index(action.public_acceptance_risk) > risk_levels.index(max_public):
                max_public = action.public_acceptance_risk
        
        return {
            "political": max_political,
            "technical": max_technical,
            "public_acceptance": max_public
        }
    
    def compare_scenarios(
        self,
        current_snapshot: Dict,
        scenario_action_lists: List[List[str]]
    ) -> List[SimulationResult]:
        """
        Vertaa useita eri skenaarioita keskenään.
        
        Args:
            current_snapshot: Nykyinen tilanne
            scenario_action_lists: Lista skenaarioita, joista kukin on lista action ID:itä
                Esim: [
                    ["demand_response_residential"],
                    ["reserve_power_activation"],
                    ["demand_response_residential", "reserve_power_activation"]
                ]
        
        Returns:
            Lista SimulationResult-objekteja, yksi per skenaario
        """
        return [
            self.simulate(current_snapshot, action_ids)
            for action_ids in scenario_action_lists
        ]


# ============================================================================
# EXAMPLE USAGE
# ============================================================================

if __name__ == "__main__":
    from decision_matrix import ACTIONS
    
    # Simuloi kriisitilanne
    crisis_snapshot = {
        "timestamp": "2026-01-31T12:00:00Z",
        "locks": {
            "Reserve": "CRITICAL",  # 0.3
            "Time": "WEAK",         # 0.7
            "Governance": "OK"      # 1.0
        },
        "signals": {
            "frequency": 49.92,
            "reserves": 350,
            "temp_med": -18.5,
            "wind_med": 3.2
        },
        "resilience_index": 0.67  # (0.3 + 0.7 + 1.0) / 3
    }
    
    simulator = ActionSimulator(ACTIONS)
    
    # Simuloi: "Mitä jos aktivoimme kysyntäjouston?"
    result = simulator.simulate(
        crisis_snapshot,
        ["demand_response_residential"]
    )
    
    print(f"Alkutilanne: Index {result.initial_state['resilience_index']:.2f}")
    print(f"Lopputilanne: Index {result.final_state['resilience_index']:.2f}")
    print(f"Muutos: {result.index_change:+.2f}")
    print(f"Aika: {result.time_to_full_effect_minutes} min")
    print(f"Kustannus: {result.total_cost_eur} EUR")
    print(f"\nLukkojen muutokset:")
    for lock, change in result.lock_changes.items():
        print(f"  {lock}: {change:+.2f}")
