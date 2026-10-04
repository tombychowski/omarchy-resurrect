# panel-integration Specification

## Purpose

Defines how the native Omarchy panel presents ress state and delegates machine-changing behavior to the CLI or an interactive terminal.

## Requirements

### Requirement: CLI Is Authoritative For Panel State
The panel SHALL obtain vault, freshness, category, and operation state through documented CLI output rather than independently inspecting or modifying the vault.

#### Scenario: Panel refreshes summary
- **WHEN** the panel needs current backup state
- **THEN** it consumes the CLI status result
- **AND** does not derive a conflicting state from vault files

#### Scenario: Malformed status is not fabricated
- **WHEN** the CLI result cannot be parsed
- **THEN** the panel discards the result rather than presenting fabricated status values

### Requirement: Backup Runs Through The CLI
The panel SHALL invoke backup through the CLI and SHALL render operation progress from the CLI consumer protocol.

#### Scenario: User starts backup in panel
- **WHEN** the user activates the backup action
- **THEN** the panel launches the CLI backup operation
- **AND** displays its reported steps and completion state

### Requirement: Restore Uses An Interactive Terminal
The panel SHALL open restore in a terminal so privilege and consent interactions remain visible and answerable.

#### Scenario: User activates restore
- **WHEN** the user selects restore from the panel
- **THEN** ress opens an interactive terminal restore flow
- **AND** the panel does not silently obtain elevated privileges

### Requirement: Backup Freshness Is Legible
The panel SHALL distinguish current, stale, missing, running, and failed backup states without presenting a stale backup as an operation failure.

#### Scenario: Backup becomes stale
- **WHEN** the last successful backup exceeds the configured freshness threshold
- **THEN** the panel changes its freshness presentation
- **AND** continues to distinguish that condition from a failed backup

### Requirement: Core Panel Actions Are Keyboard Accessible
The panel SHALL expose navigation, activation, tab switching, and closing through documented keyboard controls.

#### Scenario: Keyboard-only operation
- **WHEN** a user opens the panel and uses only the documented keys
- **THEN** the user can navigate available actions, switch tabs, activate an action, and close the panel
