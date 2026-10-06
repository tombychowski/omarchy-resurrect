# Spec Delta

## Purpose

Defines how ress reads control files from fetched vaults and loadouts without allowing untrusted repository links to escape the selected artifact root.

## ADDED Requirements

### Requirement: Control Files Are Contained Regular Files
The system SHALL read a fetched manifest, profile, inventory, list, launcher, or encrypted bundle only when the selected path is a regular non-symlink file contained beneath the expected artifact root.

#### Scenario: Fetched profile is a symlink
- **WHEN** a cloned loadout repository provides `profile.json` as a symbolic link
- **THEN** ress refuses the profile before reading the link target
- **AND** performs no loadout mutation

#### Scenario: Vault manifest is a symlink
- **WHEN** a fetched vault provides its current or supported legacy manifest as a symbolic link
- **THEN** ress refuses the vault as malformed before preview or mutation

#### Scenario: Inventory is a symlink
- **WHEN** a vault inventory or explicit encrypted bundle path is a symbolic link
- **THEN** ress refuses that input rather than reading the link target as vault content

### Requirement: Directory Replay Does Not Escape The Artifact Root
The system SHALL preserve safe contained directory content without following links that resolve outside the fetched vault subtree.

#### Scenario: Captured tree contains an escaping link
- **WHEN** a fetched configuration or Omarchy tree contains a symbolic link whose target is outside that tree
- **THEN** restore does not read or write through the escaping link
- **AND** does not use the link to select a machine mutation target
