## MODIFIED Requirements

### Requirement: Control Files Are Contained Regular Files

The system SHALL read a repository envelope, backup manifest, portable profile, Ress port control, inventory, list, launcher, or encrypted bundle only when the selected path is a regular non-symlink file contained beneath the validated repository, historical worktree, or staging root expected for that artifact.

#### Scenario: Fetched profile is a symlink

- **WHEN** a cloned loadout repository provides a selected `profile.json` as a symbolic link
- **THEN** Montage refuses the profile before reading the link target
- **AND** performs no loadout mutation

#### Scenario: Vault manifest is a symlink

- **WHEN** a fetched vault provides `montage.json` or `backup.json` as a symbolic link
- **THEN** Montage refuses the repository or backup as malformed before preview or mutation

#### Scenario: Ress port control is a symlink

- **WHEN** an explicit Ress import source provides its manifest or profile as a symbolic link
- **THEN** the port adapter refuses the artifact rather than following the link
- **AND** leaves source and destination unchanged

#### Scenario: Inventory is a symlink

- **WHEN** a backup inventory or explicit encrypted bundle path is a symbolic link
- **THEN** Montage refuses that input rather than reading the link target as backup content

### Requirement: Directory Replay Does Not Escape The Artifact Root

The system SHALL preserve safe contained directory content without following links that resolve outside the validated repository snapshot, historical worktree, or import staging subtree.

#### Scenario: Captured tree contains an escaping link

- **WHEN** a selected backup tree contains a symbolic link whose target is outside that tree
- **THEN** restore does not read or write through the escaping link
- **AND** does not use the link to select a machine mutation target

#### Scenario: Historical checkout contains an escaping link

- **WHEN** a historical backup commit is materialized for inspection or restore and contains a link escaping its isolated worktree
- **THEN** Montage refuses that linked content under the same rules as the current backup

#### Scenario: Ress staging tree contains an escaping link

- **WHEN** an import source contains a directory link that escapes the staged artifact boundary
- **THEN** the port adapter refuses the linked content and does not publish the staged repository
