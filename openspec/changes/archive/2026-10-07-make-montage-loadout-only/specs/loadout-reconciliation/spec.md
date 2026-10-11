# Spec Delta

## ADDED Requirements

### Requirement: Loadout Attention Has Stable Classifications

The system SHALL summarize authoritative applied-loadout and library evidence as healthy, drifted, repair-needed, update-available, repository-attention, operation-active, operation-partial-or-failed, or unavailable-or-invalid.

#### Scenario: Every applied claim is satisfied

- **WHEN** all validated applied loadouts are healthy and no library or operation needs attention
- **THEN** the status summary reports healthy

#### Scenario: Safely repairable resource is missing

- **WHEN** a tracked resource is missing and ordinary repair can attempt it
- **THEN** the summary reports repair-needed and identifies the affected loadout

#### Scenario: Resource differs incompatibly

- **WHEN** current resource evidence no longer matches the tracked definition
- **THEN** the summary reports drifted rather than healthy

#### Scenario: New source content is established

- **WHEN** an explicit source resolution or update preview establishes changed content for the same repository and loadout identity
- **THEN** the summary may report update-available without silently replacing desired state

#### Scenario: Repository requires a decision

- **WHEN** a configured library is invalid, unavailable, remote-ahead, divergent, or otherwise requires user action
- **THEN** the summary reports repository-attention without mutating it

### Requirement: Attention Inspection Is Non-Mutating

The system SHALL derive status and bar attention from CLI-owned state and explicit read operations without repairing resources, updating applied content, reconciling Git divergence, or inventing unavailable facts. Once the configured-repository registry is absent or schema 2, attention inspection SHALL NOT write Montage state.

#### Scenario: Panel refreshes attention after registry migration

- **WHEN** the panel requests current attention state and the configured-repository registry is absent or schema 2
- **THEN** the CLI returns the available validated summary
- **AND** performs no loadout, resource, registry, or repository mutation

#### Scenario: Optional state is malformed

- **WHEN** applied-loadout or repository state cannot be validated
- **THEN** the summary reports unavailable-or-invalid
- **AND** does not fabricate an empty or healthy result

#### Scenario: No explicit network check was requested

- **WHEN** ordinary status is refreshed
- **THEN** Montage does not contact a remote solely to claim that an update is available

### Requirement: Legacy Registry Migration Is the Sole Status Write

The system SHALL permit status-time mutation only for the locked, atomic first-read migration of a supported schema-1 configured-repository registry defined by `loadout-repositories`.

#### Scenario: Status encounters a supported legacy registry

- **WHEN** status or panel refresh first reads a supported schema-1 configured-repository registry
- **THEN** Montage may perform only the locked schema-2 migration defined by `loadout-repositories`
- **AND** reports the migration in the normal status result
- **AND** does not fetch, synchronize, or mutate any configured repository path
