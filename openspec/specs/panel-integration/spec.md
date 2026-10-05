# panel-integration Specification

## Purpose

Defines how the native Omarchy panel presents ress state and delegates machine-changing behavior to the CLI or an interactive terminal.

## Requirements

### Requirement: CLI Is Authoritative For Panel State
The panel SHALL obtain vault, freshness, category, operation, applied-loadout, resource-health, and lifecycle state through documented CLI output rather than independently inspecting or modifying vault or loadout state.

#### Scenario: Panel refreshes summary
- **WHEN** the panel needs current backup or applied-loadout state
- **THEN** it consumes the applicable CLI status or loadout query result
- **AND** does not derive a conflicting state from vault or registry files

#### Scenario: Malformed status is not fabricated
- **WHEN** a CLI status or loadout result cannot be parsed
- **THEN** the panel discards that result rather than presenting fabricated status, ownership, or health values

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

### Requirement: Panel Presents Applied Loadouts Progressively
The panel SHALL provide a keyboard-accessible Loadouts surface that summarizes tracked loadout count and attention state, lists individual lifecycle health, and reveals metadata and resource detail on request.

#### Scenario: Healthy loadouts are summarized compactly
- **WHEN** all tracked loadouts are healthy
- **THEN** the panel presents their identities and healthy state without manufacturing an alert dashboard

#### Scenario: Loadout needs attention
- **WHEN** the CLI reports missing, modified, conflicting, pending, or removal-pending resources
- **THEN** the panel identifies the affected loadout and exposes a path to its details or corrective command

#### Scenario: Keyboard-only loadout management
- **WHEN** a user operates the Loadouts surface using only documented keyboard controls
- **THEN** the user can inspect loadouts, enter a source, preview apply, and launch available repair or removal flows

### Requirement: Risky Loadout Actions Use An Interactive Terminal
The panel SHALL delegate loadout apply, repair, conflict resolution, and removal to an interactive terminal so previews, privilege requests, destructive consequences, and independent consent decisions remain visible and answerable.

#### Scenario: User removes a loadout from the panel
- **WHEN** a user activates removal for a tracked loadout
- **THEN** the panel opens the CLI removal flow in an interactive terminal
- **AND** does not delete resources directly or silently obtain elevated privileges

#### Scenario: User repairs drift from the panel
- **WHEN** a user activates repair for a degraded loadout
- **THEN** the panel opens the CLI repair flow in an interactive terminal
- **AND** leaves AUR and other CLI consent boundaries intact
