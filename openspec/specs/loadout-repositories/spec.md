# loadout-repositories Specification

## Purpose

Defines Montage's local multi-loadout Git repository, stable item identities, portable profile leaves, repository queries, and explicit synchronization with a remote GitHub repository.

## Requirements

### Requirement: A Repository Holds Multiple Loadouts
The system SHALL store a Montage loadout repository envelope in root `montage.json` and zero or more loadouts at `loadouts/<stable-id>/profile.json` without requiring a Git repository per loadout.

#### Scenario: Repository contains several loadouts
- **WHEN** the user lists a valid repository containing multiple loadout directories
- **THEN** Montage returns every validated stable id and its display metadata
- **AND** does not merge their resources or identities

#### Scenario: One loadout is updated
- **WHEN** the user confirms an update to one repository loadout
- **THEN** Montage replaces only that loadout's generated profile and metadata
- **AND** preserves every other loadout in the repository

### Requirement: Repository Identity Is Separate From Display Metadata
The system SHALL assign each repository and loadout a bounded stable identity that remains unchanged when a loadout's name, description, or contents change.

#### Scenario: Loadout display name changes
- **WHEN** a user renames an existing loadout
- **THEN** its repository path and stable identity remain unchanged
- **AND** a newly computed profile digest records the changed snapshot

#### Scenario: Hostile identity is supplied
- **WHEN** a repository or loadout identity contains traversal, separators, control characters, or other unsupported syntax
- **THEN** Montage refuses it before deriving or accessing a path

### Requirement: Portable Leaves Retain The Omarchy Loadout Format
The system SHALL store portable leaf profiles as schema-version-1 `profile.json` documents with `kind: "omarchy-loadout"` until Montage requires leaf semantics that format cannot safely represent.

#### Scenario: Portable loadout is written
- **WHEN** Montage saves a loadout using only the supported packages, pinned plugins, reconstructible web apps, and single-theme boundary
- **THEN** the leaf is independently valid as an Omarchy loadout profile
- **AND** Montage-specific repository state is not embedded as executable or cleanup authority

#### Scenario: Portable profile is opened directly
- **WHEN** a user applies a contained standalone schema-version-1 `profile.json`
- **THEN** Montage validates and previews it without requiring a Montage repository envelope

### Requirement: Repository Loadout Selection Is Explicit
The system SHALL require a stable loadout selector when a repository source contains more than one loadout and SHALL resolve that selector before planning apply or update.

#### Scenario: Remote repository contains several loadouts
- **WHEN** a user supplies a repository source and one valid stable loadout id
- **THEN** Montage validates and applies only that loadout's profile snapshot

#### Scenario: Ambiguous repository source is supplied
- **WHEN** a repository contains multiple loadouts and no valid selector is provided
- **THEN** Montage refuses to choose one implicitly
- **AND** reports the available stable identities through a non-mutating query

### Requirement: Loadout Repository Writes Are Atomic And Versioned
The system SHALL validate a complete intended repository change in staging, install it atomically while holding the repository lock, and record successful content changes as Git commits.

#### Scenario: Profile generation is refused
- **WHEN** a selected resource, repository control, or generated profile fails validation
- **THEN** Montage leaves the repository working tree, index, history, and remote unchanged

#### Scenario: Valid update changes content
- **WHEN** a validated loadout update changes repository content
- **THEN** Montage commits the complete change with inspectable metadata
- **AND** reports the resulting repository and loadout identities

### Requirement: Loadout Repository Synchronization Is Explicit
The system SHALL synchronize a configured credential-free GitHub remote only through an explicit operation or configured explicit policy and SHALL NOT force-push or silently discard divergent work.

#### Scenario: Local repository can fast-forward
- **WHEN** synchronization finds a compatible remote history that can be integrated without conflict
- **THEN** Montage updates the local repository and reports the resulting synchronization state

#### Scenario: Local and remote histories diverge
- **WHEN** synchronization cannot preserve both histories automatically
- **THEN** Montage stops without force-pushing, resetting, or choosing a side
- **AND** reports the divergence for explicit resolution

#### Scenario: Remote URL contains credentials
- **WHEN** a configured or discovered remote includes URL user information
- **THEN** Montage strips or refuses the credential-bearing form before persistence or display

### Requirement: Repository Queries Are Available Without Mutation
The system SHALL provide human-readable and JSON queries for repository identity, remote state, contained loadouts, selected profile digests, and synchronization status without rewriting repository content.

#### Scenario: Panel requests the repository catalog
- **WHEN** the panel requests the documented repository JSON query
- **THEN** the CLI returns validated repository and loadout records
- **AND** the panel need not inspect `montage.json`, Git state, or profile files itself
