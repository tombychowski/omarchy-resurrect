# Proposal

## Why

The project has diverged far enough from its Ress origin that it needs an independent product, plugin, command, persistence namespace, and format roadmap. The rename must also establish repository models that can manage multiple local loadouts and historical vault backups without coupling Montage's runtime or future schemas to the published Ress plugin.

## What Changes

- **BREAKING** Rename the product to Montage, publish it under the distinct Omarchy plugin id `tombychowski.montage`, and expose the public CLI as `mntg` rather than installing or shadowing either `ress` or ImageMagick's existing `montage` command.
- **BREAKING** Move Montage-owned configuration, operational state, data, locks, registry, and CLI links into Montage namespaces; the application does not read or write live Ress directories during ordinary operation.
- **BREAKING** Replace Ress-branded native vault controls with a Montage vault-repository format. A repository represents one machine lineage, `montage.json` identifies the repository, `backup.json` describes the snapshot in each backup commit, and Git history supplies selectable historical backups.
- Replace the single exported-profile repository with a Montage loadout repository that stores multiple stable loadout identities under `loadouts/<id>/profile.json`, has a Montage-owned `montage.json` repository envelope, and can synchronize with a credential-free GitHub remote.
- Retain `profile.json` with `kind: "omarchy-loadout"` and schema version 1 as the constrained portable leaf format. A Montage-specific leaf kind is deferred until a loadout needs semantics that cannot be represented safely by that portable format.
- Add a format-neutral, staged artifact-port framework with explicit adapters. The first adapter supports Ress schema-1 import and export: import copies and translates a current snapshot by default, optional history import translates supported Git commits, export materializes a selected Montage loadout or backup as a disposable Ress-compatible copy, and neither direction shares live state or cleanup authority.
- Add CLI and panel repository selection, history, synchronization, and migration surfaces while keeping the CLI authoritative for validation, Git actions, machine state, and mutation.
- Preserve all existing safety, consent, credential, provenance, non-destructive, and untrusted-input guarantees across native repository operations and compatibility ports.
- Reconcile the public README, vision, principles, contracts, architecture, panel language, workflows, testing documentation, site/media, release guidance, and non-historical main specs with the Montage identity. Historical changelog entries and archived OpenSpec evidence remain historically accurate.

## Capabilities

### New Capabilities

- `application-identity`: Owns Montage's plugin, CLI, IPC, filesystem namespaces, installation coexistence, and command-collision guarantees.
- `loadout-repositories`: Owns the multi-loadout local Git repository, stable loadout identities, portable leaf placement, repository queries, selection, commits, and GitHub synchronization.
- `vault-repositories`: Owns the one-machine-lineage Git vault repository, backup commits, backup listing and selection, repository synchronization, and history-aware restore inputs.
- `artifact-portability`: Owns format-adapter selection, the shared port report, lifecycle safety, destination isolation, loss consent, and extension contract for future interchange formats.
- `ress-portability`: Owns the frozen Ress schema-1 import/export boundary, staging, validation, history conversion, loss reporting, and prohibition on shared live state or cleanup authority.

### Modified Capabilities

- `schema-compatibility`: Replace Ress-native manifest naming and migration rules with Montage repository and backup schemas while retaining strict pre-mutation version validation.
- `vault-capture`: Record each successful Montage capture as a validated backup snapshot committed to the configured Montage vault repository.
- `loadout-sharing`: Store and update selected portable profiles within a multi-loadout repository instead of treating one root profile repository as the only export.
- `applied-loadouts`: Track the selected repository/loadout identity and immutable profile snapshot without importing Ress ownership claims or cleanup authority.
- `resumable-restore`: Bind preview and progress to an explicitly resolved Montage backup commit or imported snapshot.
- `cli-consumer-protocol`: Rename public command surfaces to `mntg` and expose stable repository, backup, loadout-library, synchronization, and port results.
- `panel-integration`: Present Montage identity and CLI-owned repository, backup-history, multi-loadout, synchronization, and Ress migration workflows.
- `untrusted-artifact-reading`: Extend contained-control-file and safe-directory rules to Montage repository envelopes, selected historical trees, and staged imported/exported artifacts.

## Impact

- Renames `bin/ress`, `lib/ress/`, internal symbols, test harness entrypoints, module maps, mutation targets, QML command paths, human output, and installation documentation to Montage/`mntg` equivalents.
- Changes `manifest.json`, QML module and IPC identifiers, bar/keybinding examples, repository/homepage metadata, release assets, and marketplace submission identity while leaving the existing Ress listing independent.
- Introduces native repository controls and commands, loadout repository storage, historical backup selection, GitHub synchronization policy, a format-neutral port framework, and isolated Ress-v1 adapter modules and fixtures.
- Changes default paths from Ress namespaces to Montage namespaces and replaces `~/.local/bin/ress` linking with a guarded `~/.local/bin/mntg` link.
- Requires contract updates for vault repositories, portable profiles, applied-loadout state, CLI protocols, restore safety, Git synchronization, import/export loss boundaries, and source containment.
- Requires focused automated compatibility, collision, repository, Git divergence, history-selection, atomic-port, credential, and side-by-side plugin tests plus real-machine/clean-VM evidence for rendering, installation, update/removal independence, GitHub synchronization, and historical restore.
