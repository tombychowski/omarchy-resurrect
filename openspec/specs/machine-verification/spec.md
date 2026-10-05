# machine-verification Specification

## Purpose

Defines how ress reports whether the current machine matches the reconstructible state declared by a vault.

## Requirements

### Requirement: Verification Reflects Restorable State
The system SHALL compare current machine state with entries the restore path can reconstruct and SHALL classify non-restorable inventory separately.

#### Scenario: Machine matches vault
- **WHEN** every restorable vault entry is present in the expected current state
- **THEN** verification reports a match
- **AND** exits successfully

#### Scenario: Machine differs from vault
- **WHEN** one or more restorable entries are missing or different
- **THEN** verification reports the affected categories and entries
- **AND** exits non-zero

#### Scenario: Unrestorable entry is not reported as missing
- **WHEN** a captured plugin, theme, or launcher cannot be reconstructed
- **THEN** verification reports it as refused or non-restorable rather than as a missing restorable entry

### Requirement: Verification Supports Structured Output
The system SHALL provide a JSON verification result whose category counts and item arrays preserve each logical entry.

#### Scenario: Name containing spaces remains one entry
- **WHEN** a verification item has a display name containing spaces
- **THEN** JSON output contains one array item for that logical entry

### Requirement: Status Reports Capture State Safely
The system SHALL report vault availability, backup freshness, category configuration, settings, and manifest data even when hand-edited configuration or state contains unexpected values.

#### Scenario: Invalid setting does not erase status
- **WHEN** a boolean, interval, timestamp, or manifest value is malformed
- **THEN** `status --json` still returns a valid result using safe fallback values

### Requirement: Applied Loadout Health Is Verifiable
The system SHALL compare tracked loadout desired state with the current machine and SHALL report aggregate loadout health plus structured resource-level missing, modified, conflicting, protected, pending, and unverifiable states.

#### Scenario: Every tracked loadout is healthy
- **WHEN** all non-deferred claims are present and compatible and no operation remains pending
- **THEN** applied-loadout checking reports a healthy result
- **AND** exits successfully

#### Scenario: Tracked resource is missing
- **WHEN** a resource claimed by an applied loadout was removed outside ress
- **THEN** checking identifies the resource and every affected loadout
- **AND** exits non-zero

#### Scenario: Resource cannot be safely compared
- **WHEN** ress lacks sufficient evidence to decide whether a claimed resource still matches
- **THEN** checking reports it as unverifiable rather than healthy or missing

### Requirement: Loadout Status Survives Optional State Problems
The system SHALL keep unrelated status fields usable when optional loadout summary state cannot be read, while refusing loadout mutation whenever ownership or cleanup authority is uncertain.

#### Scenario: Loadout summary is malformed
- **WHEN** status encounters malformed applied-loadout state
- **THEN** status still returns valid non-loadout fields with an explicit unavailable loadout summary
- **AND** does not fabricate an empty or healthy loadout inventory
