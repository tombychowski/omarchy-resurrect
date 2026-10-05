# Spec Delta

## ADDED Requirements

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
