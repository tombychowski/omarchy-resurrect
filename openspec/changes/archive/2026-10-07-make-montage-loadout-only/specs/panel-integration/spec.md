# Spec Delta

## MODIFIED Requirements

### Requirement: CLI Is Authoritative For Panel State

The panel SHALL obtain loadout repository, synchronization, operation, applied-loadout, resource-health, lifecycle, Share-catalog, and Ress-migration state through documented `mntg` output rather than independently inspecting or modifying repository or machine state.

#### Scenario: Panel refreshes summary

- **WHEN** the panel needs current repository, applied-loadout, or attention state
- **THEN** it consumes the applicable CLI status, repository, loadout, resource, or migration result
- **AND** does not derive conflicting state from Git, repository, profile, registry, or machine files

#### Scenario: Malformed status is not fabricated

- **WHEN** a CLI result cannot be parsed
- **THEN** the panel discards that result rather than presenting fabricated repository, ownership, synchronization, health, or attention values

### Requirement: External Operation State Tracks The Lock Owner

The panel-visible running state SHALL remain present for the lifetime of the live loadout or repository mutation that owns the primary operation lock and SHALL NOT be cleared by unrelated CLI processes.

#### Scenario: Read command exits during a live operation

- **WHEN** a loadout mutation owns the operation lock and an unrelated status, query, help, or version command exits
- **THEN** the panel continues to observe the external operation as running
- **AND** only the lock-owning operation removes its marker when it finishes

#### Scenario: Dry run owns no visible marker

- **WHEN** a dry-run operation acquires the primary lock for a coherent plan
- **THEN** it does not create or remove the panel-visible running marker

### Requirement: Panel Configures Montage Locations Without Sharing Ress State

The panel SHALL allow users to configure Montage loadout-library locations and credential-free remotes. It SHALL NOT offer vault repository types or a shared-live-directory mode for Ress configuration, loadouts, locks, or state.

#### Scenario: Repository location is changed

- **WHEN** the user submits a new Montage library location
- **THEN** the panel delegates validation and serialized configuration update to `mntg`
- **AND** does not ask for a repository kind or move, overwrite, or adopt a repository implicitly

#### Scenario: Ress location is supplied for migration

- **WHEN** the user chooses a Ress loadout profile as an import source
- **THEN** the panel or CLI workflow treats it only as a one-time migration source
- **AND** does not save it as Montage's live repository or state location

## ADDED Requirements

### Requirement: Panel Presents Loadout Libraries Progressively

The panel SHALL provide a keyboard-accessible Libraries surface for selecting and inspecting configured loadout repositories, stable loadout items, validity, synchronization state, and actions supplied by the CLI.

#### Scenario: User inspects loadout repository

- **WHEN** a configured repository contains multiple loadouts
- **THEN** the panel lists their stable identities and display metadata from CLI output
- **AND** requires an explicit loadout selection before compose, apply, or update

#### Scenario: Repository needs attention

- **WHEN** the CLI reports invalid, unavailable, remote-ahead, or divergent repository state
- **THEN** the panel presents repository attention and the applicable inspect or terminal handoff
- **AND** does not choose a history or repair action independently

### Requirement: Risky Repository And Migration Actions Use An Interactive Terminal

The panel SHALL delegate synchronization requiring conflict decisions and Ress loadout publication to an interactive terminal so previews and consent remain visible.

#### Scenario: Synchronization diverges

- **WHEN** a repository sync preview reports divergent local and remote histories
- **THEN** the panel opens the interactive `mntg` flow for review or abort
- **AND** does not force-push, reset, or merge a repository directly

#### Scenario: User confirms Ress loadout import

- **WHEN** a Ress loadout migration preview is ready for publication
- **THEN** the panel opens the interactive `mntg` import flow when that action is exposed in the panel
- **AND** leaves source and destination unchanged until CLI confirmation succeeds

### Requirement: Panel Has Three Loadout-Oriented Surfaces

The panel SHALL organize the product around Libraries, Compose/Share, and Applied Loadouts without a Backup surface.

#### Scenario: User opens the panel

- **WHEN** the panel becomes visible
- **THEN** its available navigation exposes loadout libraries, composition, and applied-loadout management
- **AND** exposes no backup, restore, retention, scheduling, or vault-history action

### Requirement: Bar Presents Loadout Attention

The bar SHALL summarize CLI-reported loadout attention and active operation state without using backup age, stale thresholds, schedules, or freshness language.

#### Scenario: All loadout state is healthy

- **WHEN** CLI status reports no applied-loadout or repository attention
- **THEN** the bar presents a healthy loadout state

#### Scenario: Repair is needed

- **WHEN** CLI status reports repair-needed or drifted applied state
- **THEN** the bar presents attention and the panel identifies the affected loadout

#### Scenario: Status is unavailable

- **WHEN** authoritative state is invalid or unavailable
- **THEN** the bar distinguishes unavailable state from healthy, active, partial, or failed state

## REMOVED Requirements

### Requirement: Backup Runs Through The CLI

**Reason**: Machine backup is no longer part of Montage.

**Migration**: Use the preserved `legacy-montage-backup-and-loadout` branch or another backup product for historical Backup/Restore behavior.

### Requirement: Restore Uses An Interactive Terminal

**Reason**: Machine restore and exact backup selection are no longer part of Montage.

**Migration**: Use the preserved combined-product branch or another recovery product; the active panel offers only Loadout workflows.

### Requirement: Backup Freshness Is Legible

**Reason**: The bar now communicates loadout attention rather than backup age.

**Migration**: Consumers must use the loadout-only status and attention classifications.

### Requirement: Panel Presents Montage Repositories Progressively

**Reason**: The combined requirement exposes both loadout libraries and vault backup history.

**Migration**: The Libraries surface is governed by `Panel Presents Loadout Libraries Progressively` and exposes only loadout repositories and stable items.

### Requirement: Risky Repository And Port Actions Use An Interactive Terminal

**Reason**: The combined requirement includes backup restore, retention deletion, general import/export, and vault publication.

**Migration**: Synchronization decisions and optional Ress loadout import use `Risky Repository And Migration Actions Use An Interactive Terminal`.
