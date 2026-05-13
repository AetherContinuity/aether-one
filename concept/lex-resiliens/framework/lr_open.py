
from __future__ import annotations
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Any, Optional, List
import json


@dataclass
class LRResult:
    """Result of an LR() assessment."""
    name: str
    R: float
    S: float
    E: float
    KRI_X: str
    status: str
    vrf_triggered: bool
    function_scores: Dict[str, float] = field(default_factory=dict)
    warnings: List[str] = field(default_factory=list)

    def summary(self) -> str:
        """Return human-readable summary."""
        lines = [
            f"LR({self.name})",
            f"{'='*60}",
            "Component Scores:",
            f"  R (Resource):     {self.R:+.2f}",
            f"  S (Social):       {self.S:+.2f}",
            f"  E (Ecological):   {self.E:+.2f}",
            "",
            f"KRI_X Index: {self.KRI_X}",
            f"Status: {self.status}",
            f"48h VRF Lock: {'🔒 TRIGGERED' if self.vrf_triggered else '✓ Not triggered'}",
        ]
        if self.warnings:
            lines.append("")
            lines.append("⚠️  Warnings:")
            for w in self.warnings:
                lines.append(f"  - {w}")
        lines.append("="*60)
        return "\n".join(lines)

    def to_dict(self) -> Dict[str, Any]:
        """Export result as dict."""
        return {
            "name": self.name,
            "components": {
                "R": round(self.R, 2),
                "S": round(self.S, 2),
                "E": round(self.E, 2),
            },
            "KRI_X": self.KRI_X,
            "status": self.status,
            "vrf_triggered": self.vrf_triggered,
            "function_scores": self.function_scores,
            "warnings": self.warnings,
        }


class LRFramework:
    """LR-Open core framework."""

    def __init__(self, core_path: Optional[str] = None) -> None:
        if core_path is None:
            core_path = "lr_open_core.json"
        self.core_path = Path(core_path)
        if not self.core_path.exists():
            raise FileNotFoundError(
                f"Configuration file not found: {self.core_path}\n"
                f"Please ensure lr_open_core.json is in the current directory."
            )
        with self.core_path.open("r", encoding="utf-8") as f:
            self.config = json.load(f)
        self.functions = {fn["id"]: fn for fn in self.config.get("functions", [])}
        self.kri_cfg = self.config.get("kri_index", {})
        self.vrf_cfg = self.config.get("vrf_lock", {})
        self.scale = self.config.get("scale", {})
        self._validate_config()

    def _validate_config(self) -> None:
        required_functions = ["RSM", "RRM", "TSM", "RAP", "IRS", "LRM"]
        missing = [f for f in required_functions if f not in self.functions]
        if missing:
            raise ValueError(f"Missing required functions in config: {missing}")

    def _clamp(self, value: float, min_val: float, max_val: float) -> float:
        return max(min_val, min(max_val, value))

    def evaluate(
        self,
        name: str,
        function_scores: Dict[str, float],
        strict: bool = True,
    ) -> LRResult:
        warnings: List[str] = []
        if strict:
            missing = [f for f in self.functions.keys() if f not in function_scores]
            if missing:
                raise ValueError(f"Missing function scores: {missing}")

        R_numer = S_numer = E_numer = 0.0
        R_denom = S_denom = E_denom = 0.0

        min_val = float(self.scale.get("min", -3))
        max_val = float(self.scale.get("max", 3))

        for fn_id, score in function_scores.items():
            fn_cfg = self.functions.get(fn_id)
            if not fn_cfg:
                warnings.append(f"Unknown function '{fn_id}' - ignoring")
                continue

            if not (min_val <= score <= max_val):
                warnings.append(
                    f"Score for {fn_id} ({score}) outside valid range "                        f"[{min_val}, {max_val}] - clamping"
                )
                score = self._clamp(score, min_val, max_val)

            affects = fn_cfg.get("affects_components", {})
            for component, weight in affects.items():
                weight = float(weight)
                if weight == 0:
                    continue
                if component == "R":
                    R_numer += weight * score
                    R_denom += abs(weight)
                elif component == "S":
                    S_numer += weight * score
                    S_denom += abs(weight)
                elif component == "E":
                    E_numer += weight * score
                    E_denom += abs(weight)

        def safe_div(num: float, den: float, default: float = 0.0) -> float:
            return num / den if den != 0 else default

        R = self._clamp(safe_div(R_numer, R_denom, 0.0), min_val, max_val)
        S = self._clamp(safe_div(S_numer, S_denom, 0.0), min_val, max_val)
        E = self._clamp(safe_div(E_numer, E_denom, 0.0), min_val, max_val)

        fmt = self.kri_cfg.get(
            "output_format",
            "KRI_X: (R{R_score} / S{S_score} / E{E_score})",
        )
        R_i = int(round(R))
        S_i = int(round(S))
        E_i = int(round(E))

        def sign_str(val: int) -> str:
            if val > 0:
                return f"+{val}"
            if val < 0:
                return f"{val}"
            return "0"

        KRI_X = fmt.format(
            R_score=sign_str(R_i),
            S_score=sign_str(S_i),
            E_score=sign_str(E_i),
        )

        status = self._determine_status(R_i, S_i, E_i)
        vrf_triggered = self._check_vrf_lock(status)
        if vrf_triggered:
            duration = self.vrf_cfg.get("default_duration_hours", 48)
            warnings.append(
                f"VRF Lock triggered – {duration}h freeze on spending/decisions"
            )

        return LRResult(
            name=name,
            R=R,
            S=S,
            E=E,
            KRI_X=KRI_X,
            status=status,
            vrf_triggered=vrf_triggered,
            function_scores=function_scores.copy(),
            warnings=warnings,
        )

    def _determine_status(self, R: int, S: int, E: int) -> str:
        rules = self.kri_cfg.get("status_rules", [])
        env = {"R": R, "S": S, "E": E, "min": min}
        for rule in rules:
            cond = rule.get("condition")
            status = rule.get("status", "Unknown")
            if not cond:
                continue
            try:
                if eval(cond, {"__builtins__": {}}, env):
                    return status
            except Exception:
                continue
        return "Unknown"

    def _check_vrf_lock(self, status: str) -> bool:
        trigger_cond = self.vrf_cfg.get(
            "trigger_condition",
            "status in ['Critical', 'Fragile']",
        )
        env = {"status": status}
        try:
            return bool(eval(trigger_cond, {"__builtins__": {}}, env))
        except Exception:
            return False

    def batch_evaluate(
        self,
        scenarios: Dict[str, Dict[str, float]]
    ) -> Dict[str, LRResult]:
        results: Dict[str, LRResult] = {}
        for name, scores in scenarios.items():
            results[name] = self.evaluate(name, scores, strict=False)
        return results


def main() -> None:
    import sys
    if len(sys.argv) < 2:
        print("Usage: python lr_open.py <scenario_file.json>")
        print("\nExample scenario file format:")
        print(json.dumps({
            "Energy2035_Mixed": {
                "RSM": 2, "RRM": 1, "TSM": 2,
                "RAP": 1, "IRS": 1, "LRM": 2
            }
        }, indent=2))
        return
    scenario_file = Path(sys.argv[1])
    if not scenario_file.exists():
        print(f"Error: File not found: {scenario_file}")
        return
    with scenario_file.open("r", encoding="utf-8") as f:
        scenarios = json.load(f)
    framework = LRFramework()
    results = framework.batch_evaluate(scenarios)
    for name, result in results.items():
        print(result.summary())
        print()


if __name__ == "__main__":
    main()
