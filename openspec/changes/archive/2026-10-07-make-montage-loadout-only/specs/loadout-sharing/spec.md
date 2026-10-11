# Spec Delta

## MODIFIED Requirements

### Requirement: Loadout Contains Only Supported Setup Actions

The system SHALL limit a loadout to packages, pinned plugins, reconstructible web apps, and a theme selection discovered from current machine state.

#### Scenario: Share excludes home content

- **WHEN** a user composes a loadout from the resource catalog
- **THEN** the loadout contains no dotfiles, secret bundle, arbitrary file content, machine identity, cleanup authority, or command field

#### Scenario: Unrepresentable launcher is omitted

- **WHEN** a detected web app requires launcher behavior the loadout format cannot represent
- **THEN** share marks it unavailable and reports the omission

## ADDED Requirements

### Requirement: Authored Share Targets A Library Item

The system SHALL require an explicitly selected loadout repository and stable loadout id when composing or publishing authored loadout content.

#### Scenario: All representable resources are shared

- **WHEN** a user runs `mntg share --repository NAME --loadout ID` without an explicit subset
- **THEN** Montage publishes all currently representable resources to that one selected item
- **AND** preserves every sibling item

#### Scenario: Library selection is missing

- **WHEN** a share invocation omits the repository or stable loadout id
- **THEN** Montage refuses to create a legacy single-profile output repository

### Requirement: Standalone Profiles Remain Applicable

The system SHALL continue to validate and preview a contained standalone schema-version-1 `profile.json` without requiring a Montage repository envelope.

#### Scenario: User applies a standalone profile

- **WHEN** a user supplies a valid local or supported remote portable profile
- **THEN** Montage previews and applies its constrained resources without treating it as authored library or cleanup state

## REMOVED Requirements

### Requirement: Whole-Machine Share Remains Compatible

**Reason**: The compatibility requirement retains legacy single-profile authoring and backup-derived language that conflicts with the library-backed Loadout product. Sharing all representable resources remains available only for an explicitly selected library item.

**Migration**: Initialize or configure a Montage loadout repository, choose a stable loadout id, and run `mntg share --repository NAME --loadout ID`. Existing portable `profile.json` leaves remain directly applicable and may be imported into a library.
