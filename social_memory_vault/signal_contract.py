"""Validation for the Signal Kernel Contract v0.1."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Mapping

from jsonschema import Draft202012Validator, FormatChecker


class SignalContractError(ValueError):
    """Raised when a signal fails structural or evidence-link validation."""


def _default_schema_path() -> Path:
    return Path(__file__).resolve().parent.parent / "schemas" / "signal.schema.json"


def load_signal_schema(schema_path: str | Path | None = None) -> dict[str, Any]:
    """Load and meta-validate the Signal Kernel JSON Schema."""
    path = Path(schema_path) if schema_path is not None else _default_schema_path()
    with path.open("r", encoding="utf-8") as handle:
        schema = json.load(handle)
    Draft202012Validator.check_schema(schema)
    return schema


def validate_signal_contract(
    signal: Mapping[str, Any],
    schema_path: str | Path | None = None,
) -> None:
    """Validate one complete source -> claim -> event -> project -> action path.

    Raises:
        SignalContractError: if JSON Schema validation or cross-reference
            validation fails.
    """
    schema = load_signal_schema(schema_path)
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    errors = sorted(validator.iter_errors(signal), key=lambda err: list(err.absolute_path))
    if errors:
        details = "; ".join(
            f"{'.'.join(map(str, error.absolute_path)) or '<root>'}: {error.message}"
            for error in errors
        )
        raise SignalContractError(f"Signal schema validation failed: {details}")

    source_id = signal["source"]["id"]
    claim = signal["claim"]
    event = signal["event"]
    project = signal["project_impact"]
    action = signal["candidate_action"]

    link_errors: list[str] = []
    if claim["source_id"] != source_id:
        link_errors.append(
            f"claim.source_id {claim['source_id']!r} does not reference source.id {source_id!r}"
        )
    if claim["id"] not in event["claim_ids"]:
        link_errors.append("event.claim_ids does not reference claim.id")
    if event["id"] not in project["event_ids"]:
        link_errors.append("project_impact.event_ids does not reference event.id")
    if event["id"] not in action["event_ids"]:
        link_errors.append("candidate_action.event_ids does not reference event.id")
    if project["project_id"] not in action["affected_project_ids"]:
        link_errors.append(
            "candidate_action.affected_project_ids does not reference project_impact.project_id"
        )

    if link_errors:
        raise SignalContractError(
            "Signal evidence path is broken: " + "; ".join(link_errors)
        )
