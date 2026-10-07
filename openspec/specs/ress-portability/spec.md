# ress-portability Specification

## Purpose

Define an explicit, bounded interchange path between Ress v1 artifacts and Montage repositories without retaining Ress as a native runtime dependency or sharing live product state.

## Requirements

### Requirement: Ress Compatibility Is A Versioned Port Boundary

The system SHALL treat Ress compatibility as import and export support for the documented Ress v1 vault and loadout formats, rather than as a promise to preserve Ress runtime behavior or follow future Ress format changes.

#### Scenario: Supported Ress artifact is identified

- **WHEN** the user asks Montage to inspect a Ress artifact
- **THEN** Montage SHALL identify the artifact type and supported Ress format version before proposing any conversion

#### Scenario: Unknown future Ress format is supplied

- **WHEN** the artifact requires a Ress format version outside the supported compatibility boundary
- **THEN** Montage SHALL refuse conversion without modifying the source or destination
- **AND** SHALL report the unsupported version and supported boundary

### Requirement: Porting Never Shares Live Product State

The system SHALL keep Montage and Ress configuration, state, locks, registries, repositories, and cleanup authority separate. Porting SHALL operate through an explicit staging and validation workflow.

#### Scenario: Ress source is imported

- **WHEN** the user imports a supported Ress vault or loadout
- **THEN** Montage SHALL read the source without changing it
- **AND** SHALL stage, translate, and validate a Montage-native result before atomically publishing it

#### Scenario: Operational state is encountered

- **WHEN** the source contains Ress configuration, locks, applied-state registries, cleanup ownership, credentials, or private keys
- **THEN** Montage SHALL NOT adopt those artifacts as Montage operational state

### Requirement: Current Snapshot Import Is The Default

The system SHALL import the selected current Ress snapshot or loadout into Montage-native storage by default, with fresh Montage repository history and no inherited remote.

#### Scenario: Current Ress vault is imported

- **WHEN** the user confirms a default Ress vault import
- **THEN** Montage SHALL create a validated Montage vault repository from the selected current snapshot
- **AND** SHALL leave Ress Git history and remotes behind

#### Scenario: Current Ress loadout is imported

- **WHEN** the user confirms a Ress loadout import into a Montage loadout repository
- **THEN** Montage SHALL add it as a new stable Montage loadout item while preserving compatible portable profile data

### Requirement: History Translation Is Explicit And Optional

The system SHALL offer Ress history translation only as an explicit import mode and SHALL report which revisions can and cannot be translated before publishing the destination.

#### Scenario: History import is requested

- **WHEN** the user requests Ress history translation
- **THEN** Montage SHALL translate supported snapshots into new Montage commits in a staging repository
- **AND** SHALL preserve the Ress source repository unchanged

#### Scenario: A historical revision is unsupported

- **WHEN** a requested Ress history contains an untranslatable revision
- **THEN** Montage SHALL stop before publishing unless the user explicitly selects a supported subset under the loss policy

### Requirement: Ress Export Produces A Disposable Compatibility Copy

The system SHALL export a selected Montage loadout or backup into a separate Ress-compatible directory without converting the Montage repository in place.

#### Scenario: Selected loadout is exported

- **WHEN** the user exports a Montage loadout for Ress
- **THEN** Montage SHALL create and validate a disposable Ress v1 loadout copy containing only representable data

#### Scenario: Selected backup is exported

- **WHEN** the user exports a Montage backup for Ress
- **THEN** Montage SHALL create and validate a disposable Ress v1 vault copy without changing the selected Montage commit or repository

### Requirement: Lossy Conversion Requires Specific Consent

The system SHALL fail closed when compatible conversion would omit data. It MAY continue only after explicit consent for reported, representational loss and SHALL never waive safety, consent, credential, or cleanup-ownership guarantees.

#### Scenario: Representational loss is detected

- **WHEN** conversion would omit Montage-only metadata that is not required for safe replay
- **THEN** Montage SHALL list the omissions and require an explicit loss-acceptance option before proceeding

#### Scenario: Safety semantics cannot be represented

- **WHEN** the target format cannot preserve a required safety, consent, credential, or ownership rule
- **THEN** Montage SHALL refuse conversion even if general loss acceptance was supplied

### Requirement: Port Operations Are Previewable And Machine Readable

The system SHALL provide non-mutating inspection and dry-run output for Ress imports and exports in both human-readable and the shared versioned port JSON form identified as format `ress-v1`.

#### Scenario: Import is previewed

- **WHEN** the user previews a Ress import
- **THEN** Montage SHALL report the detected source, proposed destination, selected snapshots, warnings, losses, and planned mutations without writing them

#### Scenario: Panel requests a port report

- **WHEN** the panel requests JSON inspection or preview output
- **THEN** the CLI SHALL return the same conversion decision data used by the mutating command

### Requirement: Self-Plugin Entries Are Never Silently Reassigned

The system SHALL treat Ress and Montage plugin identities as distinct during conversion.

#### Scenario: Ress plugin appears in an imported profile

- **WHEN** a Ress loadout includes the published Ress plugin identity
- **THEN** Montage SHALL report it explicitly and SHALL NOT silently replace it with the Montage plugin identity

#### Scenario: Montage plugin cannot be represented for Ress

- **WHEN** a Ress export encounters the Montage plugin identity
- **THEN** Montage SHALL require an explicit include, omit, or mapping decision consistent with the loss and safety rules
