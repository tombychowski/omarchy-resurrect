# ress-loadout-migration Specification

## Purpose

Defines a bounded, import-only migration path from supported Ress v1 portable loadout profiles into Montage loadout libraries without sharing runtime state or ownership.

## Requirements

### Requirement: Ress Migration Accepts Loadout Profiles Only

The system SHALL inspect and migrate only a supported Ress v1 `profile.json` that represents a portable loadout and SHALL refuse Ress vault, backup, history, or runtime-state artifacts.

#### Scenario: Supported Ress loadout is inspected

- **WHEN** the user asks Montage to inspect a contained Ress v1 loadout profile
- **THEN** Montage identifies its format and supported schema version without changing the source

#### Scenario: Ress vault is supplied

- **WHEN** the source is a Ress vault, backup, history repository, or operational-state directory
- **THEN** Montage refuses it as outside the loadout migration boundary
- **AND** proposes no vault or machine-state mutation

#### Scenario: Future profile version is supplied

- **WHEN** the profile declares an unsupported version
- **THEN** Montage reports the supported boundary and changes neither source nor destination

### Requirement: Migration Publishes One Explicit Library Item

The system SHALL require one configured Montage loadout repository and one stable loadout id, stage and validate the translated profile, and atomically publish only that selected item.

#### Scenario: Valid profile is imported

- **WHEN** the user confirms import into an explicitly selected repository and loadout id
- **THEN** Montage publishes one valid portable profile and one content-changing repository commit
- **AND** preserves sibling loadouts, repository identity, and repository remote

#### Scenario: Destination selection is incomplete

- **WHEN** repository or stable loadout identity is missing or invalid
- **THEN** Montage refuses before changing a library or its history

### Requirement: Ress Source And Authority Remain Separate

The system SHALL leave the Ress source unchanged and SHALL NOT import Ress configuration, remotes, locks, applied state, claims, cleanup ownership, credentials, private keys, or machine identity as Montage authority.

#### Scenario: Source contains operational state

- **WHEN** Ress state or ownership records are present beside the portable profile
- **THEN** Montage ignores or refuses those records rather than adopting them
- **AND** creates no applied-loadout claims during migration

#### Scenario: Imported profile is later applied

- **WHEN** the user applies the migrated library item
- **THEN** ordinary Montage planning observes the current machine and establishes native provenance and cleanup policy

### Requirement: Loss And Self-Plugin Decisions Are Explicit

The system SHALL report representational loss and Ress/Montage self-plugin entries before publication and SHALL require the exact applicable decision without allowing safety or ownership loss to be waived.

#### Scenario: Ress plugin is present

- **WHEN** the source profile contains the Ress plugin identity
- **THEN** Montage reports it explicitly and does not silently map it to the Montage plugin

#### Scenario: Non-waivable state would cross the boundary

- **WHEN** migration would require importing credentials, private keys, executable authority, or cleanup ownership
- **THEN** Montage refuses even if general representational loss was accepted

### Requirement: Migration Is Previewable And Machine Readable

The system SHALL provide non-mutating human and versioned JSON inspection or dry-run output containing source, selected destination identity, warnings, losses, compatibility, and planned publication.

#### Scenario: Migration is previewed

- **WHEN** the user requests inspection or dry run
- **THEN** Montage emits the same decision data used by the live import
- **AND** writes neither source nor destination
