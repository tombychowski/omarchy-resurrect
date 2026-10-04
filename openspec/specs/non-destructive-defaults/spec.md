# non-destructive-defaults Specification

## Purpose

Defines the default preservation guarantees that keep restore and loadout operations additive, inspectable, and recoverable.

## Requirements

### Requirement: No Implicit Removal
The system SHALL NOT uninstall packages or remove user content merely because an item is absent from a vault or loadout.

#### Scenario: Extra package remains installed
- **WHEN** the current machine has a package that is not present in the selected vault or loadout
- **THEN** restore or apply leaves that package installed

#### Scenario: Extra file remains present
- **WHEN** a restored directory contains a file that is absent from the vault
- **THEN** restore does not delete that file solely because it is absent

### Requirement: Backup Before Replacement
The system SHALL preserve an existing file before replacing it during restore.

#### Scenario: Existing file is replaced
- **WHEN** restore writes a captured file over an existing target
- **THEN** the previous target is retained as a ress backup before replacement

#### Scenario: New file needs no replacement backup
- **WHEN** restore writes to a target that does not exist
- **THEN** it creates the target without inventing a prior-file backup

### Requirement: Installation Is Additive
The system SHALL install only missing requested packages and SHALL NOT use package removal operations during restore or loadout application.

#### Scenario: Already-installed package is skipped
- **WHEN** a requested package is already installed
- **THEN** ress does not reinstall it solely to replay the vault or loadout

