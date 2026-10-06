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

### Requirement: Panel Offers Explicit Share Starting Choices
The panel SHALL require the user to initialize the Share composer from all shareable resources, the valid current export, an empty selection, or one available applied loadout before editing the selection.

#### Scenario: User chooses all shareable resources
- **WHEN** the user chooses the all-resources starting option
- **THEN** every non-theme resource the CLI catalog marks shareable is selected
- **AND** the active theme is selected when the catalog marks it shareable
- **AND** other shareable themes remain available as explicit alternatives
- **AND** the user may export immediately after satisfying metadata and non-empty requirements

#### Scenario: User updates the current export
- **WHEN** a valid current profile exists and the user chooses the current-export starting option
- **THEN** the panel restores its validated name, description, available resource selections, and unavailable placeholders from CLI output

#### Scenario: User starts from an applied loadout
- **WHEN** the user chooses an applied loadout as the starting option
- **THEN** the panel selects its currently present, healthy, definition-compatible resources reported by the CLI
- **AND** identifies missing, modified, conflicting, or otherwise unavailable preset resources that were not selected

#### Scenario: A starting source is unavailable
- **WHEN** the current export or applied-loadout presets are absent or unavailable
- **THEN** the panel disables only that starting choice with an explanation
- **AND** does not present unavailable state as an empty valid source

### Requirement: Panel Supports Additive Custom Composition
The panel SHALL let users add resources from further applied loadouts, search and toggle individual catalog resources by category, edit the loadout name and description, and select no more than one theme.

#### Scenario: Applied loadout is added to an existing selection
- **WHEN** the user adds an applied loadout after initializing the composer
- **THEN** its eligible resource identities are unioned with the current selection without duplicates
- **AND** the user's existing manual selections remain intact

#### Scenario: Added preset requests a different theme
- **WHEN** an added applied loadout requests a theme different from the selected theme
- **THEN** the panel retains the existing theme choice
- **AND** reports the conflict so the user can choose explicitly

#### Scenario: Modified preset resource is manually selected
- **WHEN** a preset resource is not added because its current definition differs from the applied snapshot but the current-machine candidate is independently shareable
- **THEN** the panel allows the user to select that current candidate manually
- **AND** makes clear that the current definition will be exported

#### Scenario: Keyboard-only composition
- **WHEN** the user operates the Share composer using only documented keyboard controls
- **THEN** the user can choose a starting source, edit metadata, search categories, toggle resources, acknowledge withdrawals, export, and return focus to panel navigation

### Requirement: Panel Makes Selective Export Consequences Explicit
The panel SHALL prevent empty export, display unavailable candidates and omission reasons, and obtain identity-specific acknowledgement before requesting removal of an unavailable resource from the current export.

#### Scenario: Selection is empty
- **WHEN** no resource is selected
- **THEN** the export action is unavailable
- **AND** the panel explains that a loadout must contain at least one resource

#### Scenario: Current-export resource became unavailable
- **WHEN** a resource restored from the current export is now missing or unshareable
- **THEN** the panel keeps it visible as unavailable
- **AND** requires explicit acknowledgement of that resource before enabling export without it

#### Scenario: Catalog changes before export
- **WHEN** the CLI refuses export because a selected or acknowledged identity became stale
- **THEN** the panel reports the refusal and refreshes the composer catalog
- **AND** does not present the previous selection as successfully exported

### Requirement: CLI Remains Authoritative For Share Composition
The panel SHALL derive candidates, current-export membership, applied-loadout preset eligibility, refusal reasons, and final export validity from documented CLI results and SHALL pass only user metadata, selected identities, and acknowledgements back to the CLI.

#### Scenario: Catalog JSON is malformed
- **WHEN** the panel cannot validate the CLI share-catalog result
- **THEN** the composer reports catalog state as unavailable
- **AND** does not inspect profile, registry, package, plugin, web-app, or theme files to reconstruct it

#### Scenario: Export is dispatched
- **WHEN** the user activates selective export
- **THEN** the panel invokes the CLI with the entered metadata, selected identities, and exact unavailable-resource acknowledgements
- **AND** the CLI performs final machine inspection and profile generation

### Requirement: External Operation State Tracks The Lock Owner
The panel-visible running state SHALL remain present for the lifetime of the live CLI process that owns the primary operation lock and SHALL NOT be cleared by unrelated CLI processes.

#### Scenario: Read command exits during a live operation
- **WHEN** a backup, restore, or loadout mutation owns the operation lock and an unrelated status, query, help, or version command exits
- **THEN** the panel continues to observe the external operation as running
- **AND** only the lock-owning operation removes its marker when it finishes

#### Scenario: Dry run owns no visible marker
- **WHEN** a dry-run operation acquires the primary lock for a coherent plan
- **THEN** it does not create or remove the panel-visible running marker

### Requirement: Panel Setting Writes Remain Serialized
CLI configuration updates initiated by the panel or terminal SHALL complete only while holding the dedicated configuration lock.

#### Scenario: Configuration lock times out
- **WHEN** a settings update cannot acquire the configuration lock within the supported timeout
- **THEN** the update fails with a clear error
- **AND** does not write configuration from an unlocked or stale read

#### Scenario: Concurrent setting writes serialize
- **WHEN** two setting updates are issued close together
- **THEN** each successful writer rereads configuration while holding the lock
- **AND** one successful update does not discard the other
