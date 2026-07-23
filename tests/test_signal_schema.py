"""Acceptance tests for Signal Kernel Contract v0.1."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from social_memory_vault.signal_contract import (
    SignalContractError,
    load_signal_schema,
    validate_signal_contract,
)


FIXTURES = Path(__file__).parent / "fixtures"


def _load(name: str) -> dict:
    with (FIXTURES / name).open("r", encoding="utf-8") as handle:
        return json.load(handle)


def test_signal_schema_is_valid_draft_2020_12() -> None:
    schema = load_signal_schema()
    assert schema["$schema"].endswith("draft/2020-12/schema")


def test_complete_evidence_path_passes() -> None:
    validate_signal_contract(_load("valid_signal.json"))


def test_missing_provenance_fails() -> None:
    with pytest.raises(SignalContractError, match="content_hash"):
        validate_signal_contract(_load("invalid_missing_provenance.json"))


def test_unsupported_action_reference_fails() -> None:
    signal = _load("valid_signal.json")
    signal["candidate_action"]["event_ids"] = ["evt_unrelated"]
    with pytest.raises(SignalContractError, match="evidence path is broken"):
        validate_signal_contract(signal)
