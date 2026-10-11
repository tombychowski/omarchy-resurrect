## ADDED Requirements

### Requirement: Publication Destinations Are Contained
The system SHALL refuse repository publication or recovery through symlinked or noncanonical destination ancestors before changing destination content.

#### Scenario: Destination ancestor is a symlink
- **WHEN** a publication target has a symlinked ancestor inside a library
- **THEN** preview and publication refuse without writing through that ancestor

### Requirement: Publication Recovery Preserves Schema One Compatibility
The system SHALL recover valid schema-1 Loadout publication journals written before the Loadout-only transition without requiring the removed Backup/Restore product.

#### Scenario: Earlier publication was interrupted
- **WHEN** an earlier schema-1 journal records an interrupted replacement
- **THEN** recovery restores or finalizes the item according to its recorded phase
- **AND** refuses malformed or escaping recovery paths

### Requirement: First Read Migration Is Reported By Every Consumer
The system SHALL include first-read configured-registry migration facts in the triggering command's normal human, JSON, or porcelain result.

#### Scenario: Share catalog triggers migration
- **WHEN** a Share catalog query first reads a supported mixed registry
- **THEN** its single JSON result reports prior/new schema and retired entry names
- **AND** a later query does not report a new migration

