# vault-capture Specification

## Purpose

Defines how ress captures portable machine configuration into a user-owned Git vault while making omissions and reconstruction gaps visible.

## Requirements

### Requirement: Category-Based Machine Capture
The system SHALL capture each enabled machine-state category into the configured vault and SHALL record the resulting category counts in the vault manifest.

#### Scenario: Enabled categories are captured
- **WHEN** a user runs `ress backup` with packages, configuration, Omarchy state, web apps, and plugins enabled
- **THEN** the vault contains the portable representation for each enabled category
- **AND** the manifest reports the captured counts

#### Scenario: Disabled category is skipped
- **WHEN** a category is disabled in configuration
- **THEN** backup does not capture that category
- **AND** the backup output identifies the category as turned off

### Requirement: Curated Configuration Boundary
The system SHALL capture configuration from an explicit include set, apply mandatory and user-configured exclusions, and report configuration it did not capture.

#### Scenario: Unlisted configuration is reported
- **WHEN** backup finds configuration below the supported configuration root that is not included
- **THEN** the vault records the uncaptured paths in its report

#### Scenario: Unsafe symlink is not followed
- **WHEN** a captured path contains a symlink that resolves outside the permitted source boundary
- **THEN** backup does not copy the referenced content
- **AND** the skipped link is reported

### Requirement: Portable Reconstruction Evidence
The system SHALL identify captured entries that a restore cannot reconstruct on another machine.

#### Scenario: Local plugin remote is reported
- **WHEN** an installed plugin or Git theme has no remotely cloneable source
- **THEN** backup names that entry as not restorable
- **AND** retains enough inventory information for verification to classify the gap accurately

#### Scenario: Unsupported web-app launcher is omitted
- **WHEN** a web-app launcher cannot be safely parsed and rebuilt
- **THEN** backup refuses that launcher
- **AND** reports the omission instead of silently claiming it will travel

