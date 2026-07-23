# Signal Kernel Contract v0.1

## Purpose

Signal Kernel converts external information into candidate actions without losing
the evidence path that justifies them. Version 0.1 intentionally supports one
complete path:

```text
source -> claim -> event -> affected project -> candidate action
```

The contract is an incubation layer inside Social Memory Vault. It does not
ingest feeds, summarize articles, execute actions, or provide a user interface.

## Non-negotiable invariant

A candidate action is invalid unless it retains a machine-checkable reference to:

1. the event that motivated it,
2. the project the action would affect,
3. the claim supporting the event, and
4. the source and evidence excerpt supporting the claim.

JSON Schema validates structure and required provenance. The Python validator
also verifies that IDs form an unbroken evidence path.

## Record components

### `source`

Preserves origin and retrieval evidence:

- stable ID
- title and publisher
- source URL
- publication and retrieval timestamps
- SHA-256 content hash
- bounded evidence excerpt

### `claim`

Captures one falsifiable statement with:

- a direct `source_id`
- status: `confirmed`, `inferred`, `disputed`, or `superseded`
- confidence from 0 to 1

Confidence is not a substitute for status or evidence.

### `event`

Represents the occurrence inferred from one or more claims. Version 0.1 stores
one event and requires it to reference the included claim.

### `project_impact`

Explains why the event matters to one project. It must reference the included
event.

### `candidate_action`

Describes a proposed, non-executed action. It includes:

- event and project references
- explicit human-approval requirement
- reversibility
- urgency
- expiration
- fixed status `candidate`

No action execution exists in this milestone.

## Validation boundary

`schemas/signal.schema.json` validates field shape, allowed values, timestamps,
hash format, and non-empty reference arrays.

`social_memory_vault.signal_contract.validate_signal_contract()` adds semantic
link validation:

```text
claim.source_id == source.id
claim.id in event.claim_ids
event.id in project_impact.event_ids
event.id in candidate_action.event_ids
project_impact.project_id in candidate_action.affected_project_ids
```

## Acceptance criteria

- `valid_signal.json` passes structural and link validation.
- `invalid_missing_provenance.json` fails because `source.content_hash` is absent.
- A candidate action referencing an unrelated event fails link validation.
- The existing Social Memory Vault tests continue to pass.
- Fixtures use synthetic data only.
- No feed ingestion, database, UI, model call, or automatic side effect is added.

## Files

```text
docs/SIGNAL_KERNEL_SPEC.md
schemas/signal.schema.json
social_memory_vault/signal_contract.py
tests/fixtures/valid_signal.json
tests/fixtures/invalid_missing_provenance.json
tests/test_signal_schema.py
```

## Verification

```bash
python -m pip install -r requirements.txt
python -m pytest
```

Expected result: the original vault tests and four Signal Contract tests pass.

## Deliberate limitations

- One source, claim, event, project impact, and action per signal record.
- Schema is loaded from the repository source tree, not yet packaged as data.
- No persistence, migrations, deduplication, contradiction resolution, scoring,
  expiration worker, or MCP interface.
- No claim extraction or model-generated action proposal.

These boundaries keep the first slice inspectable and testable.
