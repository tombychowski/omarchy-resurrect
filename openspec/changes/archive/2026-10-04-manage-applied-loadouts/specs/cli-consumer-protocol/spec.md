# Spec Delta

## MODIFIED Requirements

### Requirement: Porcelain Output Is Protocol-Only
The system SHALL emit only defined protocol records on standard output when porcelain mode is active, including loadout apply, repair, and removal lifecycle outcomes.

#### Scenario: Successful operation emits records
- **WHEN** a command runs with `--porcelain`
- **THEN** standard output contains structured step, progress, log, and completion records as applicable
- **AND** contains no decorative or explanatory prose

#### Scenario: Consumer sees skipped work
- **WHEN** an operation skips or defers a category or loadout resource in porcelain mode
- **THEN** the protocol reports that state instead of omitting it

#### Scenario: Loadout operation finishes with unresolved work
- **WHEN** apply, repair, or removal reaches its reporting path with pending, failed, conflicting, or decision-required resources
- **THEN** the terminal protocol reports a qualified non-success outcome and the affected resource states

### Requirement: JSON Commands Emit Valid JSON
The system SHALL emit one valid JSON result for commands that advertise JSON output, including meaningful fallback values when optional state cannot be parsed and stable structured records for loadouts and resources.

#### Scenario: Status consumer receives one object
- **WHEN** `ress status --json` completes
- **THEN** its standard output is a parseable JSON object

#### Scenario: Verify consumer receives item arrays
- **WHEN** `ress verify --json` completes
- **THEN** its result includes category summaries and structured item collections

#### Scenario: Loadout list consumer receives structured identities
- **WHEN** `ress loadout list --json` completes
- **THEN** its result represents each tracked loadout as one object with stable identity, metadata, lifecycle state, health, and resource counts

#### Scenario: Resource query preserves claim relationships
- **WHEN** a resource query requests JSON output
- **THEN** its result includes structured provenance, cleanup policy, observation state, expected definition, and claimant identities without requiring prose parsing

