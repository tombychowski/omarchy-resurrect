# Spec Delta

## ADDED Requirements

### Requirement: Montage Recognizes Loadout Repositories Only

The system SHALL expose only loadout repositories through native repository initialization, configuration, validation, queries, synchronization, and panel consumers.

#### Scenario: New repository is initialized

- **WHEN** a user initializes a native Montage repository
- **THEN** Montage creates a multi-loadout library with schema-version-1 `montage.json`
- **AND** the envelope has fixed `repositoryType: "loadouts"`

#### Scenario: Vault repository is supplied

- **WHEN** a path contains a native or historical vault repository envelope
- **THEN** normal Montage runtime refuses it as an unsupported repository kind
- **AND** does not inspect backup history or mutate the repository

#### Scenario: Repository command is invoked

- **WHEN** the user initializes or configures a library
- **THEN** the command does not require or accept a repository-kind choice

### Requirement: Mixed Repository Configuration Migrates Once

The system SHALL deterministically migrate a supported mixed configured-repository document by retaining valid loadout entries and retiring vault entries before installing a loadout-only registry.

#### Scenario: Registry contains loadout and vault entries

- **WHEN** Montage first reads a supported existing registry containing both kinds, including through status or panel startup
- **THEN** it installs a valid loadout-only registry containing the loadout entries with their names, paths, ids, and credential-free remotes preserved
- **AND** reports that vault entries were retired

#### Scenario: Migration is rerun

- **WHEN** the same loadout-only result is processed again
- **THEN** migration is a successful no-op with the same logical document

#### Scenario: User-owned vault path is retired

- **WHEN** a vault entry is removed from active configuration
- **THEN** Montage does not delete, rewrite, initialize, synchronize, or otherwise modify the repository at that path

#### Scenario: Preserved loadout entry is invalid

- **WHEN** a purported loadout entry fails current identity, path, remote, or envelope validation
- **THEN** migration fails without installing a partially migrated registry
- **AND** reports the offending entry for explicit correction

### Requirement: Normal Runtime Has No Vault Compatibility

The system SHALL validate the active configured-repository document as loadout-only after migration and SHALL NOT retain vault querying, synchronization, or fallback interpretation in ordinary operations.

#### Scenario: Vault entry is added after migration

- **WHEN** a hand-edited active registry introduces a vault repository type
- **THEN** Montage rejects the registry as malformed or unsupported
- **AND** does not silently preserve the vault entry
