"""
Recommendation Engine - Valitsee parhaat toimenpiteet

Analysoi nykyisen tilanteen ja suosittelee optimaalisia
toimenpide-yhdistelmiä.
"""

from typing import List, Dict, Tuple
from dataclasses import dataclass
from action_simulator import ActionSimulator, SimulationResult


@dataclass
class Recommendation:
    """Yksi suositus"""
    
    action_ids: List[str]
    action_names: List[str]
    
    # Odotettu vaikutus
    expected_index_improvement: float  # Esim: +0.15
    expected_lock_improvements: Dict[str, float]
    
    # Kustannukset ja resurssit
    total_cost_eur: float
    total_personnel: int
    time_to_effect_minutes: int
    
    # Riskit
    risk_level: str  # "low", "medium", "high"
    risk_breakdown: Dict[str, str]
    
    # Prioriteetti
    priority: int  # 1 = korkein, 2 = keskitaso, 3 = matala
    
    # Selitys
    rationale: str


class RecommendationEngine:
    """Suosittelee parhaita toimenpiteitä tilanteen perusteella"""
    
    def __init__(self, actions_catalog: List):
        self.simulator = ActionSimulator(actions_catalog)
        self.actions = {a.id: a for a in actions_catalog}
    
    def recommend(
        self,
        current_snapshot: Dict,
        max_recommendations: int = 3,
        risk_tolerance: str = "medium"  # "low", "medium", "high"
    ) -> List[Recommendation]:
        """
        Suosittele parhaat toimenpiteet nykytilanteeseen.
        
        Args:
            current_snapshot: Nykyinen SSA snapshot
            max_recommendations: Montako suositusta palautetaan
            risk_tolerance: Kuinka paljon riskejä sallitaan
        
        Returns:
            Lista suosituksia, paremmuusjärjestyksessä
        """
        
        # 1. Tunnista kriittiset lukot
        critical_locks = self._identify_critical_locks(current_snapshot)
        
        # 2. Generoi kandidaattiskenaariot
        scenarios = self._generate_scenarios(
            current_snapshot,
            critical_locks,
            risk_tolerance
        )
        
        # 3. Simuloi kaikki skenaariot
        results = self.simulator.compare_scenarios(
            current_snapshot,
            scenarios
        )
        
        # 4. Pisteitä skenaariot
        scored = self._score_scenarios(results, critical_locks, risk_tolerance)
        
        # 5. Palauta parhaat
        top_scored = sorted(scored, key=lambda x: x[1], reverse=True)[:max_recommendations]
        
        # 6. Muunna suosituksiksi
        recommendations = []
        for i, (result, score) in enumerate(top_scored):
            rec = self._result_to_recommendation(result, i + 1)
            recommendations.append(rec)
        
        return recommendations
    
    def _identify_critical_locks(self, snapshot: Dict) -> List[str]:
        """Tunnista kriittiset lukot"""
        critical = []
        for lock_name, status in snapshot["locks"].items():
            if status == "CRITICAL":
                critical.append(lock_name)
        return critical
    
    def _generate_scenarios(
        self,
        snapshot: Dict,
        critical_locks: List[str],
        risk_tolerance: str
    ) -> List[List[str]]:
        """
        Generoi kandidaattiskenaariot.
        
        Strategia:
        1. Yksittäiset toimenpiteet (matala riski)
        2. Kahden toimenpiteen yhdistelmät (keskitaso)
        3. Kolmen toimenpiteen yhdistelmät (korkea vaikutus)
        """
        
        scenarios = []
        
        # Suodata toimenpiteet jotka vaikuttavat kriittisiin lukkoihin
        relevant_actions = []
        for action_id, action in self.actions.items():
            for effect in action.effects:
                if effect.lock_name in critical_locks and effect.impact > 0:
                    relevant_actions.append(action_id)
                    break
        
        # 1. Yksittäiset toimenpiteet
        for aid in relevant_actions:
            if self._is_acceptable_risk(self.actions[aid], risk_tolerance):
                scenarios.append([aid])
        
        # 2. Kahden toimenpiteen yhdistelmät
        for i, aid1 in enumerate(relevant_actions):
            for aid2 in relevant_actions[i+1:]:
                if self._is_compatible(aid1, aid2):
                    combined_risk = self._estimate_combined_risk([aid1, aid2])
                    if self._risk_level_acceptable(combined_risk, risk_tolerance):
                        scenarios.append([aid1, aid2])
        
        # 3. Kolmen toimenpiteen yhdistelmät (vain jos risk_tolerance="high")
        if risk_tolerance == "high":
            for i, aid1 in enumerate(relevant_actions):
                for j, aid2 in enumerate(relevant_actions[i+1:], start=i+1):
                    for aid3 in relevant_actions[j+1:]:
                        if self._is_compatible(aid1, aid2) and self._is_compatible(aid2, aid3):
                            combined_risk = self._estimate_combined_risk([aid1, aid2, aid3])
                            if self._risk_level_acceptable(combined_risk, risk_tolerance):
                                scenarios.append([aid1, aid2, aid3])
        
        return scenarios
    
    def _is_acceptable_risk(self, action, risk_tolerance: str) -> bool:
        """Tarkista onko toimenpiteen riski hyväksyttävä"""
        risk_levels = {"low": 0, "medium": 1, "high": 2}
        tolerance_level = risk_levels[risk_tolerance]
        
        max_risk = max(
            risk_levels[action.political_risk],
            risk_levels[action.technical_risk],
            risk_levels[action.public_acceptance_risk]
        )
        
        return max_risk <= tolerance_level
    
    def _is_compatible(self, aid1: str, aid2: str) -> bool:
        """Tarkista ovatko kaksi toimenpidettä yhteensopivia"""
        # Esim: Ei voi tehdä sekä viestintää että kiertäviä katkoja samaan aikaan
        incompatible_pairs = [
            ("rolling_blackouts_targeted", "public_communication_preparedness"),
        ]
        
        for pair in incompatible_pairs:
            if (aid1 in pair and aid2 in pair):
                return False
        
        return True
    
    def _estimate_combined_risk(self, action_ids: List[str]) -> str:
        """Arvioi usean toimenpiteen yhdistetty riski"""
        risks = []
        for aid in action_ids:
            action = self.actions[aid]
            risks.extend([
                action.political_risk,
                action.technical_risk,
                action.public_acceptance_risk
            ])
        
        if "high" in risks:
            return "high"
        elif "medium" in risks:
            return "medium"
        else:
            return "low"
    
    def _risk_level_acceptable(self, risk: str, tolerance: str) -> bool:
        """Onko riski hyväksyttävä toleranssin mukaan"""
        risk_levels = {"low": 0, "medium": 1, "high": 2}
        return risk_levels[risk] <= risk_levels[tolerance]
    
    def _score_scenarios(
        self,
        results: List[SimulationResult],
        critical_locks: List[str],
        risk_tolerance: str
    ) -> List[Tuple[SimulationResult, float]]:
        """
        Pisteitä skenaariot.
        
        Pisteytys (0-100):
        - Index parannus: 0-40 pistettä
        - Kriittisten lukkojen parannus: 0-30 pistettä
        - Kustannustehokkuus: 0-15 pistettä
        - Riski (pienempi = parempi): 0-15 pistettä
        """
        
        scored = []
        
        for result in results:
            score = 0.0
            
            # 1. Index parannus (0-40 pistettä)
            index_improvement = result.index_change
            score += min(40, index_improvement * 200)  # 0.20 parannus = 40 pistettä
            
            # 2. Kriittisten lukkojen parannus (0-30 pistettä)
            critical_improvement = sum(
                result.lock_changes.get(lock, 0)
                for lock in critical_locks
            )
            score += min(30, critical_improvement * 150)
            
            # 3. Kustannustehokkuus (0-15 pistettä)
            # Halvempi = parempi
            if result.total_cost_eur < 50000:
                score += 15
            elif result.total_cost_eur < 150000:
                score += 10
            elif result.total_cost_eur < 300000:
                score += 5
            
            # 4. Riski (0-15 pistettä, pienempi riski = enemmän pisteitä)
            risk_score = {
                "low": {"low": 15, "medium": 10, "high": 5},
                "medium": {"low": 12, "medium": 12, "high": 8},
                "high": {"low": 10, "medium": 10, "high": 10}
            }
            
            overall_risk = self._estimate_combined_risk(result.actions_applied)
            score += risk_score[risk_tolerance][overall_risk]
            
            scored.append((result, score))
        
        return scored
    
    def _result_to_recommendation(
        self,
        result: SimulationResult,
        priority: int
    ) -> Recommendation:
        """Muunna SimulationResult Recommendation-objektiksi"""
        
        # Generoi selitys
        rationale = self._generate_rationale(result)
        
        # Arvioi kokonaisriski
        overall_risk = self._estimate_combined_risk(result.actions_applied)
        
        return Recommendation(
            action_ids=result.actions_applied,
            action_names=[self.actions[aid].name for aid in result.actions_applied],
            expected_index_improvement=result.index_change,
            expected_lock_improvements=result.lock_changes,
            total_cost_eur=result.total_cost_eur,
            total_personnel=result.total_personnel,
            time_to_effect_minutes=result.time_to_full_effect_minutes,
            risk_level=overall_risk,
            risk_breakdown=result.combined_risks,
            priority=priority,
            rationale=rationale
        )
    
    def _generate_rationale(self, result: SimulationResult) -> str:
        """Generoi selitys suositukselle"""
        
        # Tunnista suurimmat parannukset
        sorted_improvements = sorted(
            result.lock_changes.items(),
            key=lambda x: x[1],
            reverse=True
        )
        
        rationale_parts = []
        
        # Pääasiallinen vaikutus
        if sorted_improvements and sorted_improvements[0][1] > 0.1:
            lock_name, improvement = sorted_improvements[0]
            rationale_parts.append(
                f"Parantaa {lock_name}-lukon tilaa merkittävästi ({improvement:+.2f})"
            )
        
        # Indeksin parannus
        if result.index_change > 0.05:
            rationale_parts.append(
                f"Nostaa resilienssindeksiä {result.index_change:+.2f}"
            )
        
        # Nopeus
        if result.time_to_full_effect_minutes < 30:
            rationale_parts.append("Nopea käyttöönotto")
        
        # Riski
        if result.combined_risks["political"] == "low" and \
           result.combined_risks["public_acceptance"] == "low":
            rationale_parts.append("Matala poliittinen riski")
        
        return ". ".join(rationale_parts) + "."


# ============================================================================
# EXAMPLE USAGE
# ============================================================================

if __name__ == "__main__":
    from decision_matrix_full import ACTIONS
    
    crisis_snapshot = {
        "timestamp": "2026-01-31T12:00:00Z",
        "locks": {
            "Reserve": "CRITICAL",
            "Time": "WEAK",
            "Governance": "OK"
        },
        "signals": {
            "frequency": 49.92,
            "reserves": 350,
            "temp_med": -18.5,
            "wind_med": 3.2
        },
        "resilience_index": 0.67
    }
    
    engine = RecommendationEngine(ACTIONS)
    
    recommendations = engine.recommend(
        crisis_snapshot,
        max_recommendations=3,
        risk_tolerance="medium"
    )
    
    print("=== SUOSITUKSET ===\n")
    for i, rec in enumerate(recommendations, 1):
        print(f"{i}. {', '.join(rec.action_names)}")
        print(f"   Vaikutus: Index {rec.expected_index_improvement:+.2f}")
        print(f"   Aika: {rec.time_to_effect_minutes} min")
        print(f"   Kustannus: {rec.total_cost_eur:,.0f} EUR")
        print(f"   Riski: {rec.risk_level}")
        print(f"   Perustelu: {rec.rationale}")
        print()
