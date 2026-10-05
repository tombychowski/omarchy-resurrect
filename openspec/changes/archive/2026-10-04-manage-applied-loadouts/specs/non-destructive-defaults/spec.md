# Spec Delta

## ADDED Requirements

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

