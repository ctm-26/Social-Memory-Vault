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

`social_memory_vault/schemas/signal.schema.json` validates field shape, allowed
values, timestamps, hash format, and non-empty reference arrays. It is packaged
with the Python distribution and loaded through `importlib.resources`, so the
default validator works from an installed wheel as well as a source checkout.
Callers may still provide an explicit `schema_path` override.

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
- `valid_ai_governance_signal.json` passes as a second complete evidence path.
- `invalid_missing_provenance.json` fails because `source.content_hash` is absent.
- A candidate action referencing an unrelated event fails link validation.
- The complete Social Memory Vault test suite passes on supported Python versions.
- A built wheel can load the packaged schema outside the repository directory.
- Fixtures use synthetic data only.
- No feed ingestion, database, UI, model call, or automatic side effect is added.

## Synthetic governance fixture

`valid_ai_governance_signal.json` models how public security guidance can connect
to Agent Flight Recorder requirements. Its wording, URL, excerpt, and hash are
intentionally synthetic; it is a validation fixture, not an archived source.
The control themes were informed by the Australian Signals Directorate's public
agentic-AI guidance:

https://www.cyber.gov.au/about-us/view-all-content/news/careful-adoption-of-agentic-ai-in-cyber-defence

## Files

```text
.github/workflows/tests.yml
pyproject.toml
docs/SIGNAL_KERNEL_SPEC.md
social_memory_vault/schemas/__init__.py
social_memory_vault/schemas/signal.schema.json
social_memory_vault/signal_contract.py
tests/fixtures/valid_signal.json
tests/fixtures/valid_ai_governance_signal.json
tests/fixtures/invalid_missing_provenance.json
tests/test_signal_schema.py
```

## Verification

```bash
python -m pip install ".[dev]"
python -m pytest
python -m build
```

GitHub Actions runs the complete suite on Python 3.10 through 3.13, builds a
wheel, reinstalls that wheel, changes to `/tmp`, and verifies that
`load_signal_schema()` still finds the packaged resource.

## Deliberate limitations

- One source, claim, event, project impact, and action per signal record.
- No persistence, migrations, deduplication, contradiction resolution, scoring,
  expiration worker, or MCP interface.
- No claim extraction or model-generated action proposal.

These boundaries keep the first slice inspectable and testable.
