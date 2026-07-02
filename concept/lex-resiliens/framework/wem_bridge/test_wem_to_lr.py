import pytest
from wem_to_lr import WemSnapshot, compute_R, compute_S, snapshot_to_agent


def test_full_capacity_full_health():
    s = WemSnapshot(
        region_id="TEST_FULL",
        se1_flow_mw=0, se1_capacity_mw=2300,
        shortage_status=0, frequency_hz=50.00,
    )
    assert compute_R(s) == 1.0
    assert compute_S(s) == 1.0


def test_zero_margin_without_internal():
    s = WemSnapshot(
        region_id="TEST_ZERO",
        se1_flow_mw=2300, se1_capacity_mw=2300,
        shortage_status=0, frequency_hz=50.00,
    )
    assert compute_R(s) == 0.0


def test_internal_missing_uses_se1_alone():
    s = WemSnapshot(
        region_id="TEST_NO_INTERNAL",
        se1_flow_mw=1150, se1_capacity_mw=2300,  # 50% marginaali
        shortage_status=0, frequency_hz=50.00,
    )
    assert compute_R(s) == pytest.approx(0.5)


def test_internal_present_changes_weighting():
    s_without = WemSnapshot(
        region_id="A", se1_flow_mw=1150, se1_capacity_mw=2300,
        shortage_status=0, frequency_hz=50.00,
    )
    s_with = WemSnapshot(
        region_id="B", se1_flow_mw=1150, se1_capacity_mw=2300,
        internal_flow_mw=0, internal_capacity_mw=4000,  # taysi marginaali
        shortage_status=0, frequency_hz=50.00,
    )
    # ilman internal: R=0.5. Internal-marginaali=1.0 nostaa R:aa.
    assert compute_R(s_with) > compute_R(s_without)


def test_broken_capacity_is_conservative_zero():
    s = WemSnapshot(
        region_id="TEST_BROKEN",
        se1_flow_mw=100, se1_capacity_mw=0,
        shortage_status=0, frequency_hz=50.00,
    )
    assert compute_R(s) == 0.0


def test_shortage_status_3_tanks_social():
    s = WemSnapshot(
        region_id="TEST_SHORTAGE",
        se1_flow_mw=0, se1_capacity_mw=2300,
        shortage_status=3, frequency_hz=50.00,
    )
    assert compute_S(s) == 0.5  # shortage=0, freq=1 -> 0.5*0+0.5*1


def test_shortage_status_out_of_range_raises():
    s = WemSnapshot(
        region_id="TEST_INVALID",
        se1_flow_mw=0, se1_capacity_mw=2300,
        shortage_status=5, frequency_hz=50.00,
    )
    with pytest.raises(ValueError):
        compute_S(s)


def test_frequency_stepped_thresholds_not_linear():
    base = dict(region_id="X", se1_flow_mw=0, se1_capacity_mw=2300, shortage_status=0)
    stable = WemSnapshot(frequency_hz=50.05, **base)   # dev=0.05 < 0.10
    watch = WemSnapshot(frequency_hz=50.15, **base)    # dev=0.15, 0.10<=dev<0.20
    warning = WemSnapshot(frequency_hz=50.35, **base)  # dev=0.35, 0.20<=dev<0.50
    critical = WemSnapshot(frequency_hz=50.60, **base) # dev=0.60 >= 0.50
    assert compute_S(stable) == 1.0
    assert compute_S(watch) == pytest.approx(0.5 + 0.5*0.66)
    assert compute_S(warning) == pytest.approx(0.5 + 0.5*0.33)
    assert compute_S(critical) == 0.5


def test_stale_data_sets_irs_ok_zero():
    s = WemSnapshot(
        region_id="TEST_STALE",
        se1_flow_mw=0, se1_capacity_mw=2300,
        shortage_status=0, frequency_hz=50.00,
        data_fresh=False,
    )
    agent = snapshot_to_agent(s)
    assert agent["irs_ok"] == 0


def test_snapshot_to_agent_has_no_E():
    s = WemSnapshot(
        region_id="REG_TEST",
        se1_flow_mw=300, se1_capacity_mw=2300,
        shortage_status=1, frequency_hz=49.95,
    )
    agent = snapshot_to_agent(s)
    assert "E" not in agent
    assert set(agent.keys()) == {"name", "R", "S", "irs_ok", "rap_ok"}
