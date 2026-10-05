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

### Requirement: Explicit Loadout Removal Is Narrowly Scoped
The system SHALL treat confirmed removal of a tracked loadout as authority only to release that loadout's claims and remove unchanged resources that ress verifiably introduced for the final claim.

#### Scenario: Unrelated resource remains
- **WHEN** a user removes a tracked loadout
- **THEN** resources absent from that loadout's stored claims remain untouched

#### Scenario: Shared and pre-existing resources remain
- **WHEN** a claimed resource is shared by another loadout or was present before tracking
- **THEN** loadout removal leaves the machine resource in place

#### Scenario: Changed owned content is preserved
- **WHEN** a resource introduced by ress has been modified or replaced outside ress
- **THEN** loadout removal preserves it until the user makes a separate informed decision

### Requirement: Cleanup Does Not Infer Dependency Ownership
The system SHALL NOT treat unrecorded package dependencies, configuration, caches, or user data as removable merely because a tracked resource was removed.

#### Scenario: Package dependencies become orphaned
- **WHEN** removing an owned package leaves dependencies no longer required by installed packages
- **THEN** ress does not automatically remove those dependencies

#### Scenario: Application data remains
- **WHEN** an owned package, plugin, web app, or theme is removed
- **THEN** ress does not infer deletion of unrelated user configuration or data from that resource removal
