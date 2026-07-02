import pytest
from pathlib import Path
from engine import compute_all, FormulaError, SafeEvaluator

BASE = Path(__file__).parent


def test_real_facts_and_formulas_compute_without_error():
    ns = compute_all(BASE / "facts.yaml", BASE / "formulas.yaml")
    assert ns["debt_projection_2030"] == pytest.approx(324.5, abs=0.01)
    assert ns["gap_to_target_2030"] == pytest.approx(154.5, abs=0.01)
    assert ns["annual_effort_needed_for_target"] == pytest.approx(30.9, abs=0.01)


def test_unknown_variable_raises(tmp_path):
    bad = tmp_path / "bad.yaml"
    bad.write_text("x:\n  expression: \"undefined_var + 1\"\n  unit: x\n")
    with pytest.raises(FormulaError):
        compute_all(BASE / "facts.yaml", bad)


def test_key_collision_between_facts_and_formulas_raises(tmp_path):
    bad = tmp_path / "collide.yaml"
    bad.write_text("gdp_2026:\n  expression: \"1 + 1\"\n  unit: x\n")
    with pytest.raises(FormulaError):
        compute_all(BASE / "facts.yaml", bad)


def test_function_call_is_rejected():
    ev = SafeEvaluator({"a": 1.0})
    with pytest.raises(FormulaError):
        ev.eval("__import__('os').system('echo pwned')")


def test_attribute_access_is_rejected():
    ev = SafeEvaluator({"a": 1.0})
    with pytest.raises(FormulaError):
        ev.eval("a.__class__")


def test_basic_arithmetic():
    ev = SafeEvaluator({"a": 10.0, "b": 3.0})
    assert ev.eval("a + b") == 13.0
    assert ev.eval("a - b") == 7.0
    assert ev.eval("a * b") == 30.0
    assert ev.eval("a / b") == pytest.approx(3.333, abs=0.01)


def test_missing_value_field_in_facts_raises(tmp_path):
    bad_facts = tmp_path / "facts.yaml"
    bad_facts.write_text("x:\n  unit: mrd\n  source: test\n")
    empty_formulas = tmp_path / "formulas.yaml"
    empty_formulas.write_text("{}\n")
    with pytest.raises(FormulaError):
        compute_all(bad_facts, empty_formulas)
