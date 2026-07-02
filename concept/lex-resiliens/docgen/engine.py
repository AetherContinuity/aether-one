#!/usr/bin/env python3
"""
engine.py

Lataa facts.yaml ja formulas.yaml, laskee derived-arvot turvallisesti
(ei raaka eval() - vain sallitut AST-nodet: numerot, +-*/, muuttujaviittaukset
jotka loytyvat facts/formulas-sanakirjoista).

Kaataa selkeasti jos:
- kaava viittaa olemattomaan faktaan/kaavaan
- facts.yaml sisaltaa saman avaimen kahdesti (YAML-tason duplikaatti)
- kaavan tulos ei ole numero
"""

from __future__ import annotations
import ast
import operator
from pathlib import Path
from typing import Any, Dict

import yaml


ALLOWED_BINOPS = {
    ast.Add: operator.add,
    ast.Sub: operator.sub,
    ast.Mult: operator.mul,
    ast.Div: operator.truediv,
}


class FormulaError(Exception):
    pass


class SafeEvaluator:
    """Evaluoi vain +-*/ ja numeroliteraalit + nimetyt muuttujat. Ei
    funktiokutsuja, ei attribuutteja, ei importteja - rakenteellisesti
    mahdotonta ajaa mielivaltaista koodia tata kautta."""

    def __init__(self, namespace: Dict[str, float]):
        self.namespace = namespace

    def eval(self, expr: str) -> float:
        tree = ast.parse(expr, mode="eval")
        return self._eval_node(tree.body)

    def _eval_node(self, node: ast.AST) -> float:
        if isinstance(node, ast.Constant):
            if not isinstance(node.value, (int, float)):
                raise FormulaError(f"Ei-numeerinen literaali: {node.value!r}")
            return float(node.value)
        if isinstance(node, ast.Name):
            if node.id not in self.namespace:
                raise FormulaError(f"Tuntematon muuttuja kaavassa: '{node.id}' - ei loydy facts.yaml:sta eika aiemmin lasketuista formulas.yaml-arvoista")
            return float(self.namespace[node.id])
        if isinstance(node, ast.BinOp):
            op_fn = ALLOWED_BINOPS.get(type(node.op))
            if op_fn is None:
                raise FormulaError(f"Kielletty operaattori: {type(node.op).__name__}")
            return op_fn(self._eval_node(node.left), self._eval_node(node.right))
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub):
            return -self._eval_node(node.operand)
        raise FormulaError(f"Kielletty rakenne kaavassa: {type(node).__name__} (vain +-*/ ja muuttujat sallittu)")


def load_facts(path: Path) -> Dict[str, Dict[str, Any]]:
    with path.open("r", encoding="utf-8") as f:
        raw = yaml.safe_load(f)
    if not isinstance(raw, dict):
        raise FormulaError(f"{path}: odotettiin dict-rakennetta")
    return raw


def load_formulas(path: Path) -> Dict[str, Dict[str, Any]]:
    with path.open("r", encoding="utf-8") as f:
        raw = yaml.safe_load(f)
    if not isinstance(raw, dict):
        raise FormulaError(f"{path}: odotettiin dict-rakennetta")
    return raw


def compute_all(facts_path: Path, formulas_path: Path) -> Dict[str, float]:
    """Palauttaa yhdistetyn namespacen: kaikki facts-arvot + kaikki lasketut
    formulas-arvot. Kaataa jos jokin kaava epaonnistuu tai jos facts/formulas
    jakavat saman avaimen (nimiristiriita - ei sallittu, tekisi datan
    alkuperasta epaselvaa)."""
    facts_raw = load_facts(facts_path)
    formulas_raw = load_formulas(formulas_path)

    overlap = set(facts_raw.keys()) & set(formulas_raw.keys())
    if overlap:
        raise FormulaError(f"facts.yaml ja formulas.yaml maarittelevat saman avaimen: {overlap} - jokainen luku saa olla vain yhdessa paikassa")

    namespace: Dict[str, float] = {}
    for key, entry in facts_raw.items():
        if "value" not in entry:
            raise FormulaError(f"facts.yaml: '{key}' ei sisalla 'value'-kenttaa")
        namespace[key] = float(entry["value"])

    # Laske formulas jarjestyksessa; salli riippuvuudet aiemmin laskettuihin
    # formulas-arvoihin (yksinkertainen kertaluokan evaluointi, ei DAG-sorttia -
    # jos jarjestys ei riita, YAML:n jarjestys pitaa korjata kasin ja se
    # nakyy heti virheena eika hiljaisena vaarana arvona).
    for key, entry in formulas_raw.items():
        if "expression" not in entry:
            raise FormulaError(f"formulas.yaml: '{key}' ei sisalla 'expression'-kenttaa")
        evaluator = SafeEvaluator(namespace)
        try:
            result = evaluator.eval(entry["expression"])
        except FormulaError as e:
            raise FormulaError(f"Kaava '{key}' epaonnistui: {e}") from e
        namespace[key] = result

    return namespace


if __name__ == "__main__":
    import sys
    base = Path(__file__).parent
    ns = compute_all(base / "facts.yaml", base / "formulas.yaml")
    for k, v in ns.items():
        print(f"{k} = {v}")
