import json
import pytest
from pathlib import Path
from trustlog import TrustLog
from golden_runner import GoldenCheck, run_golden_checks


def test_append_and_chain(tmp_path):
    log = TrustLog(tmp_path / "test.log")
    h1 = log.append({"event": "A", "value": 1})
    h2 = log.append({"event": "B", "value": 2})
    assert h1 != h2
    records = log.read_all()
    assert len(records) == 2
    assert records[0]["prev_hash"] == ""
    assert records[1]["prev_hash"] == h1


def test_verify_ok_on_untouched_log(tmp_path):
    log = TrustLog(tmp_path / "test.log")
    log.append({"event": "A"})
    log.append({"event": "B"})
    ok, err = log.verify()
    assert ok is True
    assert err is None


def test_verify_empty_log_is_ok(tmp_path):
    log = TrustLog(tmp_path / "nonexistent.log")
    ok, err = log.verify()
    assert ok is True


def test_tamper_detected_and_restored(tmp_path):
    log = TrustLog(tmp_path / "test.log")
    log.append({"event": "A", "note": "original"})
    log.append({"event": "B", "note": "original2"})

    detected = log.tamper_test()
    assert detected is True

    # loki palautunut ennalleen tamperoinnin jalkeen
    ok, err = log.verify()
    assert ok is True
    records = log.read_all()
    assert records[1]["note"] == "original2"  # ei jaanyt "[TAMPEROITU]"-lisaysta


def test_domain_agnostic_pizza_orders(tmp_path):
    """Todiste etta trustlog ei tieda mitaan LR:sta - sama koodi
    ketjuttaa pizzatilauksia yhta hyvin kuin resilienssidataa."""
    log = TrustLog(tmp_path / "orders.log")
    log.append({"order_id": "ORD-1", "pizza": "margherita", "price_eur": 9.5})
    log.append({"order_id": "ORD-2", "pizza": "pepperoni", "price_eur": 11.0})
    log.append({"order_id": "ORD-3", "pizza": "margherita", "price_eur": 9.5})

    ok, err = log.verify()
    assert ok is True

    checks = [
        GoldenCheck(
            name="viimeisin_margherita_hinta_oikea",
            scenario_key_field="pizza",
            scenario_key_value="margherita",
            assertions=[
                lambda r: (r["price_eur"] == 9.5, f"price_eur={r['price_eur']}"),
                lambda r: (r["order_id"] == "ORD-3", f"order_id={r['order_id']} (pitaisi olla viimeisin)"),
            ],
        ),
        GoldenCheck(
            name="ei_olemassaoleva_tuote_epaonnistuu",
            scenario_key_field="pizza",
            scenario_key_value="hawaii",
            assertions=[lambda r: (True, "ei pitaisi paasta tanne")],
        ),
    ]
    results = run_golden_checks(log, checks)
    assert results[0].passed is True
    assert results[1].passed is False  # hawaii-tilausta ei ole -> oikein epaonnistuu


def test_tampered_field_content_is_restored_exactly(tmp_path):
    log = TrustLog(tmp_path / "t.log")
    original_note = "tarkka alkuperainen teksti"
    log.append({"note": original_note})
    log.tamper_test()
    records = log.read_all()
    assert records[0]["note"] == original_note
