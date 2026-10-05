# cli-consumer-protocol Specification

## Purpose

Defines machine-readable CLI surfaces used by the panel and automation so consumers receive stable records without parsing human prose.

## Requirements

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

### Requirement: Protocol And Human Output Remain Separable
The system SHALL keep protocol output free from prose while retaining human-readable explanations outside protocol mode.

#### Scenario: Human mode explains a warning
- **WHEN** a user runs a command without porcelain or JSON mode and a warning occurs
- **THEN** ress presents a readable explanation rather than requiring protocol interpretation

### Requirement: Share Catalog Is A Stable Consumer Surface
The system SHALL provide one valid JSON share-catalog result containing stable resource identities, kinds, display metadata, shareability states and reasons, current-export metadata and membership, and applied-loadout preset membership.

#### Scenario: Panel requests the share catalog
- **WHEN** the share catalog JSON command completes successfully
- **THEN** standard output contains exactly one parseable JSON object
- **AND** each selectable or unavailable resource is represented as one structured record with a stable identity

#### Scenario: Optional preset state is unavailable
- **WHEN** applied-loadout state cannot be validated but current-machine discovery succeeds
- **THEN** the catalog reports applied-loadout presets as unavailable rather than fabricating an empty healthy list
- **AND** still reports independently validated machine candidates and current-export state

#### Scenario: Current export is absent or invalid
- **WHEN** the default profile does not exist or cannot be validated
- **THEN** the catalog distinguishes absent or unavailable current-export state from a valid empty selection

### Requirement: Selective Share Outcomes Are Machine-Readable
The system SHALL keep selective-share porcelain output protocol-only and SHALL report a qualified terminal outcome and affected resource identities when validation or acknowledgement prevents export.

#### Scenario: Selective export succeeds
- **WHEN** a valid non-empty selection is exported in porcelain mode
- **THEN** standard output contains only defined protocol records
- **AND** the terminal record reports success and the profile location

#### Scenario: Selection is refused
- **WHEN** an unknown, stale, unavailable, empty, or multi-theme selection is submitted in porcelain mode
- **THEN** protocol records identify the refused resource or selection condition
- **AND** the terminal record does not report unqualified success

#### Scenario: Withdrawal acknowledgement is required
- **WHEN** selective export would drop an unavailable current-profile resource without an identity-specific acknowledgement
- **THEN** the protocol reports that resource and the required acknowledgement state
- **AND** no prose is mixed into standard output
