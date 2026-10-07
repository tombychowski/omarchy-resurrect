## MODIFIED Requirements

### Requirement: Category-Based Machine Capture

The system SHALL capture each enabled machine-state category into the selected Montage vault repository, record the resulting category counts in `backup.json`, validate the snapshot, and create a Git commit only after capture succeeds.

#### Scenario: Enabled categories are captured

- **WHEN** a user runs `mntg backup` with packages, configuration, Omarchy state, web apps, and plugins enabled
- **THEN** the selected vault repository contains the portable representation for each enabled category
- **AND** `backup.json` reports the captured counts
- **AND** the completed snapshot is committed to that repository's history

#### Scenario: Disabled category is skipped

- **WHEN** a category is disabled in Montage configuration
- **THEN** backup does not capture that category
- **AND** the backup output identifies the category as turned off

## ADDED Requirements

### Requirement: Montage Operational Artifacts Are Excluded From Capture

The system SHALL exclude Montage configuration, state, locks, credentials, repository internals, CLI links, and replacement files from portable machine capture unless a future contract explicitly defines a safe representation.

#### Scenario: Selected vault is below a captured root

- **WHEN** the configured vault repository is reachable from a captured configuration path
- **THEN** backup SHALL exclude the repository and its Git metadata
- **AND** SHALL report the exclusion without recursively capturing itself

#### Scenario: Montage replacement file is encountered

- **WHEN** capture encounters a file ending in `.montage-bak`
- **THEN** backup SHALL exclude it from the portable snapshot and report the omission
