# Spec Delta

## ADDED Requirements

### Requirement: Loadout JSON Commands Emit Valid JSON

The system SHALL emit one valid JSON result for commands that advertise JSON output, including meaningful unavailable values when optional state cannot be validated and stable structured records for status, loadout repositories, sharing, applied loadouts, Ress migration, and resources.

#### Scenario: Status consumer receives one object

- **WHEN** `mntg status --json` completes
- **THEN** standard output contains one parseable loadout-attention object

#### Scenario: Loadout list consumer receives structured identities

- **WHEN** `mntg loadout list --json` completes
- **THEN** its result represents each tracked loadout with stable identity, immutable source identity, metadata, lifecycle state, attention, and resource counts

#### Scenario: Resource query preserves claim relationships

- **WHEN** a resource query requests JSON output
- **THEN** its result includes structured provenance, cleanup policy, observation state, expected definition, and claimant identities without requiring prose parsing

#### Scenario: Invalid optional state is reported

- **WHEN** status cannot validate an applied registry or configured library
- **THEN** the result remains parseable and marks that source unavailable or invalid
- **AND** does not fabricate healthy or empty state

### Requirement: Loadout Repository And Migration Queries Are Stable Consumer Surfaces

The system SHALL expose versioned JSON inspection and preview results for configured loadout repositories, contained loadout items, synchronization state, and supported Ress loadout migration without requiring consumers to invoke Git or interpret artifact files independently.

#### Scenario: Panel lists repository content

- **WHEN** the panel requests loadout repository data
- **THEN** `mntg` returns stable repository and item identities, display metadata, validity, and relevant attention or synchronization state in one JSON result

#### Scenario: Panel previews synchronization

- **WHEN** the panel requests a sync preview
- **THEN** `mntg` reports proposed fetch, push, fast-forward, refusal, or decision-required outcomes without changing the repository

#### Scenario: Ress loadout migration is inspected

- **WHEN** a consumer requests inspection or dry-run import of a supported Ress loadout
- **THEN** `mntg` returns one versioned migration result with source, destination identities, compatibility, warnings, losses, decisions, and publication state

### Requirement: Status Is Loadout Only

The system SHALL expose loadout and library attention plus operation state without backup timestamps, freshness, schedules, capture categories, vault paths, backup manifests, or restore progress.

#### Scenario: Healthy state is requested

- **WHEN** configured libraries and applied loadouts are valid and require no action
- **THEN** `mntg status --json` reports healthy loadout attention

#### Scenario: Operation is active

- **WHEN** a loadout mutation owns the current operation marker
- **THEN** status reports active operation state without identifying it as backup activity

### Requirement: Removed Commands Have No Consumer Protocol

The system SHALL NOT advertise or emit Montage backup, restore, backup-history, retention, vault, verification, scan, secret-transport, or export-to-Ress result kinds.

#### Scenario: Consumer invokes a removed command

- **WHEN** a caller requests a removed Backup/Restore or export operation
- **THEN** the CLI rejects it as an unknown or unsupported command
- **AND** does not route it through a compatibility protocol

## REMOVED Requirements

### Requirement: JSON Commands Emit Valid JSON

**Reason**: The combined JSON contract includes backup verification and mixed repository/backup records that are removed from the Loadout product.

**Migration**: Consumers use `Loadout JSON Commands Emit Valid JSON` for status, repositories, sharing, applied loadouts, migration, and resources.

### Requirement: Repository And Port Queries Are Stable Consumer Surfaces

**Reason**: The combined query contract includes backup history and a general import/export port framework.

**Migration**: Consumers use `Loadout Repository And Migration Queries Are Stable Consumer Surfaces` for loadout libraries, synchronization, and import-only Ress loadout migration.
