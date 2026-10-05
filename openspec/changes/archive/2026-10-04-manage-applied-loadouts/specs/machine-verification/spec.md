# Spec Delta

## ADDED Requirements

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

