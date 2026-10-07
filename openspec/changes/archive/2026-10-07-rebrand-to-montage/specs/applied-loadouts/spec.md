## MODIFIED Requirements

### Requirement: Confirmed Loadouts Become Desired State

The system SHALL record each confirmed loadout as machine-local desired state using a local identity, validated profile snapshot, profile digest, sanitized source metadata, repository and stable loadout identities when available, resolved commit, timestamps, resource claims, and per-resource outcomes.

#### Scenario: Already-satisfied loadout is recorded

- **WHEN** a user confirms a valid loadout whose resources are already present
- **THEN** Montage records the loadout and its claims without reinstalling those resources

#### Scenario: Partial application remains visible

- **WHEN** one or more resource actions fail or gated work is deferred after confirmation
- **THEN** Montage retains the loadout with pending or degraded outcomes
- **AND** does not report the loadout as fully healthy

#### Scenario: Preview and cancellation create no desired state

- **WHEN** a user performs a dry run or declines the apply confirmation
- **THEN** Montage does not create a tracked loadout or resource claim

### Requirement: Resource Claims Preserve Baseline Provenance

The system SHALL assign each canonical resource a cleanup policy from its pre-mutation baseline and SHALL retain that policy across later observation and repair.

#### Scenario: Existing resource is protected

- **WHEN** the first tracked loadout claim finds a compatible resource already present
- **THEN** Montage records that the resource pre-existed tracking
- **AND** marks it for retention when its final claim is removed

#### Scenario: Missing resource is introduced by Montage

- **WHEN** the first tracked claim finds a resource absent and Montage successfully creates it
- **THEN** Montage records that it introduced the resource
- **AND** permits cleanup only after all claims are gone and the resource remains safe to remove

#### Scenario: Repair does not adopt a protected resource

- **WHEN** a protected pre-existing resource is later missing and Montage repairs it
- **THEN** the resource retains its protected cleanup policy

### Requirement: Compatible Resources Can Be Shared

The system SHALL associate a compatible canonical resource with every tracked loadout that requests it without repeating an unnecessary installation.

#### Scenario: Two loadouts request the same package

- **WHEN** a second loadout requests a package already claimed by another loadout
- **THEN** Montage adds the second claim
- **AND** does not reinstall the package solely to add that claim

#### Scenario: Equivalent pinned plugin is shared

- **WHEN** multiple loadouts request the same plugin identifier, safe remote, and pinned commit
- **THEN** Montage represents one resource with multiple loadout claimants

### Requirement: Incompatible Resource Claims Are Refused

The system SHALL compare resource definitions that share a canonical identity and SHALL refuse to treat incompatible definitions as satisfied or shared without explicit conflict resolution.

#### Scenario: Plugin commit conflicts

- **WHEN** a loadout requests an existing plugin identifier at a different remote or commit
- **THEN** Montage reports the conflict before mutation
- **AND** does not add a satisfied claim for the incompatible plugin

#### Scenario: Web app definition conflicts

- **WHEN** a loadout requests an existing web-app label with a different URL or relevant launcher definition
- **THEN** Montage reports the conflict rather than silently skipping it as already installed

### Requirement: Loadout State Is Local And Versioned

The system SHALL keep applied-loadout state in an inspectable, versioned Montage-local registry that is not exported through a vault, loadout, or Ress port and SHALL validate it before using it for mutation.

#### Scenario: Registry stays with one machine

- **WHEN** a vault is captured, a loadout is shared, or a Ress artifact is exported
- **THEN** the applied-loadout registry and its ownership observations are not included

#### Scenario: Unsupported registry version is refused

- **WHEN** the local registry declares an unsupported or malformed version
- **THEN** Montage refuses loadout mutation without guessing provenance or cleanup policy

#### Scenario: Hostile registry identifier cannot choose a path

- **WHEN** a registry resource contains an invalid identifier or deletion-oriented path content
- **THEN** Montage refuses that entry before passing it to an external command or deriving a mutation target

### Requirement: Loadout And Resource Relationships Are Queryable

The system SHALL provide human-readable and JSON queries for tracked loadouts, stored content, lifecycle health, immutable source identity, resource provenance, cleanup policy, current observation, and claimants.

#### Scenario: List applied loadouts

- **WHEN** a user lists loadouts with details or content requested
- **THEN** Montage returns each local identity, repository and loadout source identity when available, resolved commit, metadata, lifecycle state, and requested stored snapshot detail without refetching its source

#### Scenario: Inspect one resource

- **WHEN** a user queries a canonical resource
- **THEN** Montage reports whether it pre-existed tracking or was introduced by Montage
- **AND** lists every tracked loadout that currently claims it

### Requirement: Profile Replacement Is Explicit

The system SHALL identify an exact reapplication by its stored profile digest and immutable source identity and SHALL require an explicit previewed update before replacing a tracked loadout with changed profile content.

#### Scenario: Exact profile is reapplied

- **WHEN** a profile digest and source identity already belong to a tracked loadout and the user applies the same validated content again
- **THEN** Montage targets the existing local loadout for reconciliation rather than creating an indistinguishable duplicate

#### Scenario: Source now contains changed content

- **WHEN** a known repository and stable loadout identity resolves to a different commit or profile digest
- **THEN** ordinary apply does not silently replace the tracked snapshot or withdraw its claims
- **AND** directs the user to an explicit loadout update or a separately identified new application

#### Scenario: Update previews claim changes

- **WHEN** a user requests an update of a tracked loadout from changed validated content
- **THEN** Montage previews added, retained, conflicting, and withdrawn claims before confirmation
- **AND** withdrawn claims use the same preservation and cleanup rules as explicit loadout removal

### Requirement: Historical Ownership Is Not Guessed

The system SHALL treat resources found present during first registration after upgrade or Ress import as protected unless the user explicitly supplies a supported ownership decision.

#### Scenario: Old application is registered after upgrade

- **WHEN** a user reapplies a loadout after upgrading from a version that did not track applications
- **THEN** currently present compatible resources are recorded as pre-existing
- **AND** Montage does not claim that an earlier version installed them

#### Scenario: Ress artifact is imported

- **WHEN** an imported Ress loadout corresponds to resources already present on the machine
- **THEN** Montage records those resources as protected if the user later applies the imported loadout
- **AND** does not inherit Ress cleanup ownership

### Requirement: Loadout Mutations Are Serialized And Recoverable

The system SHALL serialize apply, repair, and removal with other Montage machine mutations and SHALL persist enough operation state to distinguish completed, pending, failed, and uncertain resource actions.

#### Scenario: Concurrent loadout operation is refused

- **WHEN** another Montage mutation holds the operation lock
- **THEN** a loadout apply, repair, or removal does not mutate machine or registry state concurrently

#### Scenario: Mutation succeeds before outcome recording

- **WHEN** an operation is interrupted after an external mutation but before its final outcome is recorded
- **THEN** the next run reports the action as uncertain and reconciles current evidence without classifying it as pre-existing by default
