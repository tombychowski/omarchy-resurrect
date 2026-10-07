## MODIFIED Requirements

### Requirement: CLI Is Authoritative For Panel State

The panel SHALL obtain repository, vault, backup history, freshness, category, synchronization, operation, applied-loadout, resource-health, lifecycle, and Ress-port state through documented `mntg` output rather than independently inspecting or modifying repository or machine state.

#### Scenario: Panel refreshes summary

- **WHEN** the panel needs current repository, backup, or applied-loadout state
- **THEN** it consumes the applicable CLI status, repository, history, or loadout query result
- **AND** does not derive a conflicting state from Git, repository, snapshot, or registry files

#### Scenario: Malformed status is not fabricated

- **WHEN** a CLI result cannot be parsed
- **THEN** the panel discards that result rather than presenting fabricated repository, ownership, synchronization, or health values

### Requirement: Backup Runs Through The CLI

The panel SHALL invoke backup for the selected Montage vault repository through `mntg` and SHALL render operation progress from the CLI consumer protocol.

#### Scenario: User starts backup in panel

- **WHEN** the user activates the backup action for a selected vault repository
- **THEN** the panel launches the corresponding `mntg backup` operation
- **AND** displays its reported steps and completion state

### Requirement: Restore Uses An Interactive Terminal

The panel SHALL open `mntg restore` for an explicitly selected backup in a terminal so source identity, privilege, and consent interactions remain visible and answerable.

#### Scenario: User activates restore

- **WHEN** the user selects a repository backup and activates restore from the panel
- **THEN** Montage opens an interactive terminal restore flow pinned to that backup commit
- **AND** the panel does not silently obtain elevated privileges

### Requirement: Panel Offers Explicit Share Starting Choices

The panel SHALL require the user to initialize the Share composer for a selected repository loadout from all shareable resources, that selected loadout's valid profile, an empty selection, or one available applied loadout before editing the selection.

#### Scenario: User chooses all shareable resources

- **WHEN** the user chooses the all-resources starting option
- **THEN** every non-theme resource the CLI catalog marks shareable is selected
- **AND** the active theme is selected when the catalog marks it shareable
- **AND** other shareable themes remain available as explicit alternatives
- **AND** the user may update the loadout after satisfying metadata and non-empty requirements

#### Scenario: User updates the current export

- **WHEN** a valid selected repository profile exists and the user chooses it as the starting option
- **THEN** the panel restores its validated name, description, available resource selections, and unavailable placeholders from CLI output

#### Scenario: User starts from an applied loadout

- **WHEN** the user chooses an applied loadout as the starting option
- **THEN** the panel selects its currently present, healthy, definition-compatible resources reported by the CLI
- **AND** identifies missing, modified, conflicting, or otherwise unavailable preset resources that were not selected

#### Scenario: A starting source is unavailable

- **WHEN** the selected repository profile or applied-loadout presets are absent or unavailable
- **THEN** the panel disables only that starting choice with an explanation
- **AND** does not present unavailable state as an empty valid source

### Requirement: Panel Makes Selective Export Consequences Explicit

The panel SHALL prevent empty loadout updates, display unavailable candidates and omission reasons, and obtain identity-specific acknowledgement before requesting removal of an unavailable resource from the selected repository loadout.

#### Scenario: Selection is empty

- **WHEN** no resource is selected
- **THEN** the update action is unavailable
- **AND** the panel explains that a loadout must contain at least one resource

#### Scenario: Current-export resource became unavailable

- **WHEN** a resource restored from the selected loadout is now missing or unshareable
- **THEN** the panel keeps it visible as unavailable
- **AND** requires explicit acknowledgement of that resource before enabling an update without it

#### Scenario: Catalog changes before export

- **WHEN** the CLI refuses the update because a selected or acknowledged identity became stale
- **THEN** the panel reports the refusal and refreshes the composer catalog
- **AND** does not present the previous selection as successfully written

### Requirement: CLI Remains Authoritative For Share Composition

The panel SHALL derive candidates, selected-loadout membership, applied-loadout preset eligibility, refusal reasons, and final update validity from documented CLI results and SHALL pass only repository selection, user metadata, selected identities, and acknowledgements back to the CLI.

#### Scenario: Catalog JSON is malformed

- **WHEN** the panel cannot validate the CLI share-catalog result
- **THEN** the composer reports catalog state as unavailable
- **AND** does not inspect repository, profile, registry, package, plugin, web-app, or theme files to reconstruct it

#### Scenario: Export is dispatched

- **WHEN** the user activates a selective loadout update
- **THEN** the panel invokes the CLI with repository and loadout identities, entered metadata, selected resource identities, and exact unavailable-resource acknowledgements
- **AND** the CLI performs final machine inspection, profile generation, validation, and atomic repository update

## ADDED Requirements

### Requirement: Panel Presents Montage Repositories Progressively

The panel SHALL provide keyboard-accessible surfaces for selecting and inspecting configured loadout and vault repositories, their items or backup history, validity, synchronization state, and actions supplied by the CLI.

#### Scenario: User inspects loadout repository

- **WHEN** a configured loadout repository contains multiple loadouts
- **THEN** the panel lists their stable identities and display metadata from CLI output
- **AND** requires an explicit loadout selection before apply or update

#### Scenario: User inspects vault history

- **WHEN** a configured vault repository contains multiple backup commits
- **THEN** the panel lists CLI-reported timestamps, labels, summaries, and immutable commit identities
- **AND** permits preview of a selected backup without checking out or parsing Git itself

### Requirement: Panel Configures Montage Locations Without Sharing Ress State

The panel SHALL allow users to configure Montage loadout and vault repository locations and credential-free remotes. It SHALL NOT offer a shared-live-directory mode for Ress configuration, vaults, loadouts, locks, or state.

#### Scenario: Repository location is changed

- **WHEN** the user submits a new Montage repository location
- **THEN** the panel delegates validation and serialized configuration update to `mntg`
- **AND** does not move, overwrite, or adopt an existing repository implicitly

#### Scenario: Ress location is supplied for migration

- **WHEN** the user chooses a Ress artifact as an import source
- **THEN** the panel treats it as a one-time port source and presents the CLI conversion preview
- **AND** does not save it as Montage's live repository or state location

### Requirement: Risky Repository And Port Actions Use An Interactive Terminal

The panel SHALL delegate synchronization that requires conflict decisions, backup restore, retention deletion, and Ress import or export publication to an interactive terminal so previews and consent remain visible.

#### Scenario: Synchronization diverges

- **WHEN** a repository sync preview reports divergent local and remote histories
- **THEN** the panel opens the interactive `mntg` flow for the user to resolve or abort
- **AND** does not force-push or reset a repository directly

#### Scenario: User confirms Ress import

- **WHEN** a Ress import preview is ready for publication
- **THEN** the panel opens the interactive `mntg` import flow
- **AND** leaves the source and destination unchanged until CLI confirmation succeeds
