# Loadout-Only Deletion Inventory

This checklist turns the design inventory into reviewable implementation state.
`Delete` means absent from the active product. `Refactor` names the surviving
owner. `Historical` is an intentional non-product exception. Items remain
unchecked until their disposition is true in the working tree.

## CLI And Modules

- [x] **Delete:** top-level `backup`, backup history/show/label/unlabel/retain, `restore`, backup `verify`, `scan`, `enable-units`, `diff`, vault `init`, and `secrets` help, options, dispatch, and protocols.
- [x] **Delete:** all files under `lib/montage/vault/` after surviving application commands and test guarantees move.
- [x] **Refactor → `lib/montage/commands.sh`:** `status`, `set`, `doctor`, and `link` with loadout-only behavior.
- [x] **Retain → `lib/montage/machine/packages.sh`:** installed-package/theme observation and AUR helpers used by Loadout apply/reconciliation.
- [x] **Delete:** `lib/montage/port/export.sh`, vault/history import code, native-to-Ress translation, and unused general adapter dispatch.
- [x] **Refactor → focused Ress v1 loadout migration:** contained inspect, preview, decision reporting, staging, validation, and one-item publication.
- [x] **Delete:** vault branches in repository envelope, registry, command, sync, reader, transaction, and safety code.
- [x] **Retain → loadout repository layer:** stable ids, schema-1 loadout envelopes, exact commit reads, locks, atomic transactions, recovery journals, and conservative sync.

## Commands And Protocols

- [x] **Retain:** `repository <init|list|show|validate|configure|remove|loadouts|loadout|sync>` with no kind selector.
- [x] **Retain:** `share`, `apply`, `loadout <list|show|check|repair|update|remove>`, and `resource <list|show>` JSON/porcelain surfaces.
- [x] **Retain:** `port ress inspect` and `port ress import loadout` only.
- [x] **Retain:** loadout-only `status`, `set AUR=...`, `doctor`, and `link [--remove]`.
- [x] **Delete:** backup/vault/restore/retention/verification/scan/secret/scheduler records and the extensible bidirectional `montage-port-report` contract.
- [x] **Retain/refactor:** one versioned Ress loadout migration result and parseable loadout status/repository/lifecycle/resource results.

## Configuration And Persistent State

- [x] **Delete:** `VAULT`, vault `REMOTE`, `AUTO_BACKUP`, `AUTO_INTERVAL_HOURS`, `AUTO_PUSH`, all `INCLUDE_*`, `SECRETS_MODE`, `SECRETS_RECIPIENT`, `PROFILE_URL`, `ENABLE_UNITS`, `SECRET_SCAN`, and `CAPTURE_AUTOSTART` settings.
- [x] **Retain:** ordered, locked AUR policy configuration; ignore obsolete hand-edited keys and omit them on next save.
- [x] **Delete:** vault defaults/categories and backup freshness stamps, scan findings, restore progress/failures/first-contact/unit decisions, scheduler state, and backup-only service metadata.
- [x] **Retain:** applied-loadout registry, claims, provenance, repository locks/journals, running-marker ownership, and bounded temporary cleanup.
- [x] **Migrate:** schema-1 configured repository registry to schema 2, preserving valid loadout entries and retiring vault entries atomically.
- [x] **Retain for rollback:** non-overwritten mode-0600 pre-migration registry copy; normal runtime never reads it.
- [x] **Preserve user data:** never open for mutation, rewrite, sync, initialize, or delete retired vault repository paths.

## Repository And Ress Behavior

- [x] **Delete:** vault initialization/configuration/validation/query/sync, machine lineage, backup commits/history/labels/retention, visibility warnings, and vault payload validators.
- [x] **Retain:** native schema-1 `montage.json` with fixed `repositoryType: "loadouts"`.
- [x] **Delete:** Ress vault import, history translation, backup export, loadout export, lineage translation, encrypted-secret transport, and operational-state adoption.
- [x] **Retain:** read-only Ress v1 profile inspection and explicit one-item import with loss/self-plugin decisions and no imported authority.

## Dependencies And Services

- [x] **Delete:** `age`, backup-only `rsync` usage, backup scheduler/timer/service commands, and vault-specific history/visibility tooling from active installation and diagnostics.
- [x] **Retain:** Git, jq, Omarchy, package/AUR tools, loadout repository synchronization, and panel integration dependencies actually used by retained workflows.

## Panel

- [x] **Delete:** Backup tab, freshness/age/stale threshold, history, labels, retention, restore, secrets, schedule, vault selection, and general port/export UI.
- [x] **Refactor → Libraries:** configured library/item inspection, validation, synchronization attention, selection, and terminal handoff.
- [x] **Refactor → Compose/Share:** CLI catalog, exact selection, and publication to one library item.
- [x] **Refactor → Applied Loadouts:** list/show/check/repair/update/remove and resource provenance/claims.
- [x] **Refactor → bar attention:** healthy, drifted, repair-needed, update-available, repository-attention, active, partial/failed, and unavailable/invalid.
- [x] **Retain:** CLI authority; QML does not read Git, registries, profiles, or machine state directly.

## Documentation And Specifications

- [x] **Delete from current docs:** `docs/contracts/vault-format.md`, `docs/contracts/restore-safety.md`, backup/restore and encrypted-secret workflows, and general bidirectional port architecture/workflow.
- [x] **Rewrite:** vision, principles, repository/CLI contracts, system/module/application architecture, panel docs, share/apply and sync workflows, testing guidance, and fresh-machine validation.
- [x] **Rewrite:** `README.md`, `site/public/index.html`, marketplace/plugin/release copy, and current Montage media descriptions around the three Loadout surfaces.
- [x] **Retain:** `site/archive/ress-assets/`, `docs/media/archive/`, and `openspec/changes/archive/` as clearly historical material, excluded from current-surface searches.
- [x] **Archive handoff recorded:** after implementation evidence is reviewed, archive this change so its Loadout deltas become main truth and retired Backup/Restore capability containers do not remain current. Archival is intentionally outside this apply step.

## Tests And Fixtures

- [x] **Extract/retain:** AUR consent/defer/retry; additive apply; claim-scoped cleanup; pre-existing/shared/changed/unverifiable preservation.
- [x] **Extract/retain:** credential stripping; contained/symlink-safe reads; hostile schema/version rejection; exact source/repository/loadout/commit identity.
- [x] **Extract/retain:** command/link ownership; CLI JSON/porcelain; repository lock/transaction/recovery; pinned plugin/theme behavior; applied provenance.
- [x] **Delete after extraction:** backup/vault/restore/secret/scheduler/export/history-only cases and fixtures, including Ress vault/history trees and encrypted fixture data.
- [x] **Refactor:** `tests/mutate.sh`, `tests/module-dependencies.tsv`, `tests/static-entrypoints.txt`, and structural allowlists to surviving owners.
- [x] **Retain:** historical-only strings in archived OpenSpec/media/site assets; every active-source remainder must be a tested refusal, migration record, or the legacy branch name.

## Verification

- [x] Focused command, AUR, lifecycle, repository, transaction, sync, Ress migration, status, QML, URL credential, untrusted-input, and structure cases pass.
- [x] `./tests/run.sh`, `./tests/mutate.sh`, `./tests/check-structure.sh .`, and `openspec validate --all --strict` pass after final deletion.
- [x] Disposable-real-tool, rendered-panel, network, and fresh-VM results are recorded as pass/fail/deferred with environment and commit; deferrals are not presented as passes.
