# vault-repositories Specification

## Purpose

Defines Montage's Git-backed vault repository as one machine lineage with validated backup commits, selectable history, explicit retention controls, and safe synchronization to private storage.

## Requirements

### Requirement: A Vault Repository Represents One Machine Lineage
The system SHALL identify a Montage vault repository with root `montage.json`, a stable vault identity, and one current `backup.json` snapshot while using Git history for earlier backups.

#### Scenario: New vault repository is initialized
- **WHEN** a user initializes a Montage vault
- **THEN** Montage creates a repository envelope for one machine lineage
- **AND** does not place loadout-library or applied-loadout registry state in that repository

#### Scenario: Repository identity changes unexpectedly
- **WHEN** a configured vault path resolves to a different valid repository identity during an operation
- **THEN** Montage refuses to reuse stale planning or restore progress for the prior identity

### Requirement: Successful Captures Become Backup Commits
The system SHALL validate the complete current snapshot and record each content-changing successful capture as one Git commit in the vault repository.

#### Scenario: Backup changes captured state
- **WHEN** capture and the credential gate complete successfully with changed content
- **THEN** the repository commit contains a valid `backup.json` and the matching captured payload
- **AND** Montage reports the resulting commit as the backup identity

#### Scenario: Backup is blocked before commit
- **WHEN** capture fails validation or a blocking credential scan finds plaintext risk
- **THEN** Montage creates no successful backup commit
- **AND** does not report the rejected working tree as a restorable backup

### Requirement: Backup History Is Selectable And Inspectable
The system SHALL provide human-readable and JSON operations that list and show validated backup commits and select one exact backup for preview, verification, or restore.

#### Scenario: User lists backups
- **WHEN** the user queries a valid vault repository
- **THEN** Montage returns each supported backup identity, creation metadata, source machine evidence, and optional user label without checking out or mutating it

#### Scenario: User selects an older backup
- **WHEN** the user names an exact supported commit or Montage-managed backup label
- **THEN** Montage reads and validates that commit's snapshot in isolation
- **AND** uses it as the sole source for subsequent preview or restore

#### Scenario: Selected commit is not a valid backup
- **WHEN** a supplied ref lacks a valid contained repository envelope, backup manifest, or payload boundary
- **THEN** Montage refuses it before machine mutation

### Requirement: Backup Labels And Removal Are Explicit
The system SHALL make backup labeling and history removal explicit operations and SHALL preserve reachable backups unless the user requests a previewed retention action.

#### Scenario: User labels a backup
- **WHEN** a user assigns a valid unique label to a supported backup
- **THEN** later queries and restore selection can resolve that label to the same commit

#### Scenario: Retention would discard history
- **WHEN** a retention operation would make one or more backups unreachable
- **THEN** Montage previews the affected backup identities
- **AND** requires confirmation before changing repository references

### Requirement: Vault Synchronization Preserves Local And Remote History
The system SHALL synchronize a configured credential-free remote without force-pushing, silently resetting, or treating an unresolved divergence as success.

#### Scenario: Backup history pushes normally
- **WHEN** local history is ahead of its configured private GitHub remote and can be pushed without rewriting remote history
- **THEN** Montage pushes the reachable backup commits and reports synchronization success

#### Scenario: Remote history diverged
- **WHEN** the remote and local vault histories cannot be reconciled without a user decision
- **THEN** Montage preserves both existing histories
- **AND** reports the divergence without changing machine state or backup contents

#### Scenario: Remote carries credentials
- **WHEN** a vault remote contains URL user information
- **THEN** Montage removes or refuses that form before persistence, output, or generated instructions

### Requirement: Vault Repository Remains Private By Guidance
The system SHALL identify vault synchronization as private-storage behavior and SHALL warn before configuring a remote known to be publicly visible when that visibility can be determined safely.

#### Scenario: User configures a known public GitHub repository
- **WHEN** Montage can establish that the selected vault remote is public
- **THEN** it warns that configuration and encrypted-secret ciphertext are personal backup material
- **AND** requires explicit confirmation before saving or pushing to that remote
