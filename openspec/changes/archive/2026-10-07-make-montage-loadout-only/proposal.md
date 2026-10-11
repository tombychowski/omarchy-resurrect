# Proposal

## Why

Montage currently presents two different products through one command, repository model, panel, and documentation system: private machine Backup/Restore and portable Loadout composition and lifecycle management. The product decision is now final that Montage means Loadouts, so the active product must remove Backup/Restore completely rather than retain it as hidden compatibility behavior; the combined implementation remains available on `legacy-montage-backup-and-loadout`.

## What Changes

- **BREAKING** Remove machine capture, backup history and labels, retention, vault repositories and machine lineage, restore and resume state, backup verification, encrypted-secret backup transport, backup scheduling and freshness, and every corresponding CLI, JSON/porcelain, panel, configuration, state, Ress-port, documentation, and test surface.
- Preserve the complete Loadout lifecycle: Compose, Share/Publish, Inspect, Apply, Check, Repair, Update, and Remove.
- Keep multi-loadout Git libraries, stable loadout identities, constrained `profile.json` leaves, exact repository/loadout/commit provenance, pinned plugin and theme commits, explicit AUR consent, applied-loadout claims, pre-existing-resource protection, synchronization, and authoritative CLI consumer output.
- Replace backup freshness in status and the bar with loadout attention, including healthy, drifted, repair-needed, update-available, repository-attention, active, partial/failed, and unavailable/invalid states.
- Migrate an existing mixed `repositories.json` once by preserving valid loadout entries and retiring vault entries without touching user-owned vault repositories. The migration is deterministic, explicit, and safe to rerun; normal runtime thereafter recognizes loadout repositories only.
- Retain schema-version-1 native loadout repository envelopes with fixed `repositoryType: "loadouts"` to avoid an unrelated repository-format migration.
- Replace the broad bidirectional Ress port surface with import-only Ress v1 loadout migration: inspect and validate one contained `profile.json`, report loss and self-plugin decisions, and import it into an explicitly selected library item without adopting Ress ownership or cleanup authority.
- Relocate and narrow `status`, `set`, `doctor`, and `link` before deleting the vault implementation. Preserve neutral package observation and AUR helpers used by loadout apply and reconciliation.
- Replace the four-tab Backup-oriented panel with approximately Libraries, Compose/Share, and Applied Loadouts while keeping the CLI authoritative.
- Extract Loadout safety evidence from mixed tests before deleting backup fixtures, then reconcile contracts, workflows, architecture, panel language, README/site/release material, and testing guidance.

## Capabilities

### New Capabilities

- `loadout-preservation`: Additive apply and narrowly authorized removal that preserve unrelated, shared, pre-existing, changed, and unverifiable resources.
- `loadout-execution-consent`: Independent AUR build consent and truthful deferred outcomes for apply and repair.
- `ress-loadout-migration`: Import-only inspection and migration of supported Ress v1 loadout profiles into one selected Montage library item.

### Modified Capabilities

- `loadout-sharing`: Make library-backed composition and publication the authored Share surface, remove backup-derived wording and legacy standalone authoring compatibility, and retain credential-free constrained profiles and standalone-profile application.
- `loadout-repositories`: Make repositories loadout-only and add the one-time loadout-preserving mixed-registry migration.
- `loadout-reconciliation`: Define loadout attention, including drift, repair need, update availability, repository attention, and invalid or unavailable state.
- `cli-consumer-protocol`: Remove backup, restore, vault, retention, verification, and bidirectional port records; define loadout-only status, repository, Share, lifecycle, operation, and Ress migration results.
- `panel-integration`: Replace backup freshness, scheduling, history, retention, restore, and vault porting with the three Loadout-oriented surfaces and attention semantics.
- `schema-compatibility`: Limit native compatibility to loadout repositories, portable profiles, applied state, and Ress loadout migration.
- `untrusted-artifact-reading`: Retain contained loadout and migration reads while removing vault manifests, backup payload, encrypted bundle, and restore replay behavior.
- `artifact-portability`: Retire the broad multi-artifact import/export and history-translation framework in favor of the focused Ress loadout migration capability.
- `ress-portability`: Remove Ress vault import/history, all Montage-to-Ress export, and other vault-specific interoperability in favor of `ress-loadout-migration`.
- `explicit-execution-consent`: Retire the mixed restore/service/autostart capability after moving surviving AUR guarantees to `loadout-execution-consent`.
- `non-destructive-defaults`: Retire the mixed restore/loadout capability after moving surviving Loadout guarantees to `loadout-preservation`.
- `credential-protection`: Remove backup scanning and encrypted-secret transport after retaining URL credential protection in Loadout sharing and repositories.
- `machine-verification`: Remove vault verification and backup-oriented status after retaining applied-state health in Loadout reconciliation.
- `resumable-restore`: Remove the restore-only capability.
- `vault-capture`: Remove the capture-only capability.
- `vault-repositories`: Remove the vault-only capability.

## Impact

- **CLI and modules:** `bin/mntg`, `lib/montage/core.sh`, `vault/*`, repository modules, port modules, neutral machine operations, and general command ownership.
- **Persistent state:** configuration schema, configured-repository registry migration, operation/status state, and removal of backup-only stamps, progress, findings, and scheduler state. User-owned vault repositories remain untouched.
- **Panel and plugin:** `Panel.qml`, `Service.qml`, `Model.js`, `manifest.json`, keyboard/status language, service registration, and terminal handoffs.
- **Contracts and documentation:** vision/principles, repository and CLI contracts, removal of vault/restore/secret contracts and workflows, narrowed Ress migration, architecture, testing, README, site, media, marketplace, and release copy.
- **Tests and evidence:** mixed test extraction, backup fixture deletion, loadout-only module/dependency maps, mutation targets, full automated validation, and fresh-Omarchy rendered/real-operation evidence.
- **Dependencies:** `age`, backup-only `rsync` paths, scheduling, and vault-specific Git/history infrastructure cease to be product dependencies; Git, jq, Omarchy, package/AUR tooling, and loadout repository synchronization remain.
