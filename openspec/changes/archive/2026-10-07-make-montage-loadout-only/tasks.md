# Tasks

## 1. Establish The Loadout-Only Behavioral Truth

- [x] 1.1 Record a clean pre-change baseline with `./tests/run.sh`, `./tests/check-structure.sh .`, and `openspec validate --all --strict`; save any unrelated failures as explicit prerequisites rather than weakening the new requirements.
- [x] 1.2 Add target command-routing and help characterization for the retained `repository`, `share`, `apply`, `loadout`, `resource`, `port ress`, `status`, `set`, `doctor`, and `link` surfaces, and verify the focused command-routing case expresses the final accepted syntax without adding compatibility aliases.
- [x] 1.3 Add protocol fixtures/assertions for the loadout-only status classifications and retained JSON/porcelain commands, and verify each JSON invocation produces exactly one parseable object and each porcelain stream contains only documented records.
- [x] 1.4 Add a reviewed source/command/config/state/UI/docs/test deletion checklist derived from `design.md`, and verify every inventory item has a final owner, an explicit deletion, or an approved historical-only exception.
- [x] 1.5 Update the testing strategy's transition section with the planned automated, disposable-real-tool, rendered-panel, and fresh-VM evidence boundaries, and verify it does not present unexecuted validation as a current pass.

## 2. Extract Loadout Coverage From Mixed Tests

- [x] 2.1 Split AUR apply/repair assertions out of mixed restore cases into focused Loadout tests covering separate consent, review mode, denied-package filtering, deferred state, and machine-readable outcomes; verify the focused AUR cases pass independently.
- [x] 2.2 Split additive apply and safe removal assertions into focused tests for unrelated, shared, pre-existing, changed, and unverifiable resources plus no inferred dependency or application-data cleanup; verify the apply/claims/remove case set passes independently.
- [x] 2.3 Extract credential-free URL, contained regular-file, symlink-safe tree-read, and hostile schema/version assertions into sharing, repository, and Ress-migration tests; verify each test fails against an intentional unsafe fixture and passes against its valid counterpart.
- [x] 2.4 Extract source/repository/loadout/commit identity, pinned plugin/theme, and applied-provenance assertions into focused lifecycle cases; verify apply, check, repair, update, and remove retain exact identities and pins.
- [x] 2.5 Extract CLI startup, relocated/symlinked invocation, link ownership, JSON/porcelain, repository locking/atomicity/recovery, and content-sensitive commit assertions from mixed cases; verify these focused cases pass before any source deletion.
- [x] 2.6 Repoint `tests/mutate.sh`, `tests/module-dependencies.tsv`, `tests/static-entrypoints.txt`, and structural checks at the extracted Loadout owners, and verify every moved safety guarantee still has a unique mutation detector and reviewed dependency edge.

## 3. Narrow Ress Portability To Loadout Import

- [x] 3.1 Define the focused Ress v1 loadout inspection/import command parsing and versioned result contract, and verify unsupported format ids, Ress vaults, backup/history trees, future profile versions, and missing destination selection fail before mutation.
- [x] 3.2 Implement contained regular-file discovery and validation for one Ress v1 `profile.json`, reusing native profile validation where applicable; verify symlink, traversal, hostile JSON, credentials, private keys, and executable-authority fixtures are refused.
- [x] 3.3 Implement explicit representational-loss and Ress/Montage self-plugin decisions shared by inspection, dry run, and live import; verify decision reports are identical across preview/live planning and non-waivable losses remain refusals.
- [x] 3.4 Publish one translated profile into an explicitly selected configured library item through the repository transaction boundary; verify siblings, repository id, remote, source bytes, and clean-tree state are preserved and only a content change creates a commit.
- [x] 3.5 Remove Ress vault import, vault history translation, every Ress export, machine-lineage/secret paths, and unused generic port adapter/framework branches; verify removed invocations are unknown/unsupported and no deleted function remains reachable from `bin/mntg`.
- [x] 3.6 Update the Ress migration workflow, CLI contract, and migration architecture for import-only behavior, and verify every documented example runs against the focused tests and no current document promises export, vault, or history conversion.
- [x] 3.7 Run the focused Ress fixture, inspection, loadout-import, loss-safety, transaction, and untrusted-input cases plus structure checks; verify source immutability and destination rollback are proven before deleting old port fixtures.

## 4. Simplify Repositories And Migrate Mixed Registry State

- [x] 4.1 Implement configured-repository schema 2 with the existing entry fields and fixed `type: "loadouts"`, while retaining schema-1 native loadout `montage.json`; verify new registries and repositories serialize deterministically and exact-schema validation rejects extra or vault fields.
- [x] 4.2 Implement locked schema-1 registry migration with a reread, full retained-entry validation, deterministic ordering, one revision increment, atomic replacement, and a non-overwritten mode-0600 pre-migration copy; verify concurrent and interrupted attempts cannot install a partial document.
- [x] 4.3 Emit prior/new schema and retired vault names through human, JSON, and porcelain result paths without polluting protocol stdout; verify first-read reporting and schema-2 retry/no-op results are stable and parseable.
- [x] 4.4 Add migration cases for mixed, loadout-only, vault-only, empty, malformed, credential-bearing, duplicate-name, missing-path, id-mismatch, envelope-mismatch, and hand-edited post-migration vault registries; verify an invalid retained loadout blocks the whole migration and names the offender.
- [x] 4.5 Prove retired vault paths are never opened, initialized, fetched, synchronized, rewritten, or removed by using sentinel fixtures and command doubles; verify byte/content/metadata observations remain unchanged across migration.
- [x] 4.6 Remove repository-kind choices and vault branches from init/configure/list/show/validate/loadouts/loadout/sync while retaining loadout identity, history reads needed by provenance/update, transaction recovery, and divergence safety; verify vault envelopes are rejected before payload/history inspection.
- [x] 4.7 Update the repository-format and CLI contracts plus repository architecture/workflow for schema-2 configured registries and schema-1 loadout envelopes; verify contract examples match emitted JSON and rollback documents the exact preserved registry copy.
- [x] 4.8 Run focused repository envelope, registry, transaction, commands, loadout-library, sync, credential, containment, and migration cases; verify `./tests/check-structure.sh .` shows no repository-to-vault dependency.

## 5. Relocate General Commands Out Of The Vault Layer

- [x] 5.1 Create a neutral application-command owner for `status`, `set`, `doctor`, and `link`, move the surviving functions without source-time I/O, and update the literal module list; verify direct, symlinked, relocated, and incomplete-tree startup cases.
- [x] 5.2 Narrow `set` and the ordered configuration schema to retained Loadout settings, including `AUR`, with serialized locked writes and safe malformed-value fallback; verify accepted/rejected values and concurrent write behavior.
- [x] 5.3 Narrow `doctor` to required Loadout tools, paths, repository configuration, and machine capabilities; verify it no longer requires `age`, backup-only `rsync` behavior, vault privacy, restore tooling, or scheduler state.
- [x] 5.4 Preserve exact `mntg` link ownership and removal behavior under the new module owner; verify Montage refuses to overwrite or remove a foreign link and manages its own direct and relocated links.
- [x] 5.5 Audit `machine/packages.sh` and shared core/safety helpers, keeping installed-package/theme observation and AUR operations needed by Loadout lifecycle while separating any backup-only callers; verify focused apply/check/repair/update/remove and AUR tests pass.
- [x] 5.6 Update CLI module architecture and command/config contract ownership for the relocated commands, and verify the file table, dependency map, and actual literal source order agree.
- [x] 5.7 Move mutation targets and focused tests with the relocated functions, and verify no detector references `vault/commands.sh` for surviving behavior.

## 6. Remove Vault Routing And Modules

- [x] 6.1 Remove `backup`, backup history/show/label/unlabel/retain, `restore`, backup-oriented `verify`, `scan`, `enable-units`, `diff`, vault `init`, and `secrets` from usage, global options, dispatch, aliases, and protocol declarations; verify each removed invocation fails as an unknown command before any state or network access.
- [x] 6.2 Remove every `lib/montage/vault/` file and its literal source-list entries only after phases 2 and 5 are green; verify CLI startup succeeds and no active shell/QML/test source calls a deleted vault function.
- [x] 6.3 Remove vault payload/history/lineage/label/retention/private-visibility branches from shared repository, safety, and helper code; verify retained loadout historical reads and synchronization still pass focused tests.
- [x] 6.4 Remove backup, restore, secret-transport, machine-lineage, and vault protocol records and fixtures; verify retained JSON/porcelain commands remain versioned and parseable and removed records cannot be emitted.
- [x] 6.5 Update the active CLI usage and architecture diagrams to the loadout-only module graph, and verify documentation links resolve and no current diagram includes a vault node.
- [x] 6.6 Run command-routing, CLI-module, loadout lifecycle, repository, protocol, structure, and mutation subsets; verify there is no reverse or residual dependency on `lib/montage/vault/`.

## 7. Simplify Configuration, State, Dependencies, And Status

- [x] 7.1 Remove backup-only core constants, categories, paths, and settings (`VAULT`, vault `REMOTE`, `AUTO_*`, `INCLUDE_*`, `SECRETS_*`, `PROFILE_URL`, `ENABLE_UNITS`, `SECRET_SCAN`, and `CAPTURE_AUTOSTART`), ignoring obsolete config lines on read and omitting them on the next save; verify retained AUR config and malformed-input handling.
- [x] 7.2 Remove exact readers/writers for backup freshness, findings, restore progress/failures/first-contact/unit decisions, and scheduler state without recursively cleaning shared roots; verify loadout registries, repository journals/locks, vault paths, and the pre-migration registry copy remain untouched.
- [x] 7.3 Remove `age`, backup-only `rsync`, scheduler, and vault-specific Git/history dependencies from install/package/doctor/manifest surfaces after an active-caller audit; verify dependency checks and packaging contain every tool still required by Loadout workflows.
- [x] 7.4 Implement loadout status detail aggregation and the specified precedence across active, partial/failed, unavailable/invalid, repository-attention, drifted, repair-needed, update-available, and healthy; verify multiple simultaneous causes preserve all details while selecting the expected summary.
- [x] 7.5 Make ordinary status strictly local and non-mutating once the configured registry is absent or schema 2, with update-available sourced only from explicit prior resolution/update evidence; verify command doubles observe no fetch, sync, repair, apply, update, registry write, or repository write in that steady state, while the separate schema-1 migration case proves the sole locked registry-write exception and untouched repository paths.
- [x] 7.6 Distinguish valid empty state from malformed optional applied/repository/operation state; verify malformed evidence produces unavailable-or-invalid rather than healthy or an empty fabricated result.
- [x] 7.7 Update CLI/status contracts, system/state architecture, status language, and configuration documentation for the loadout-only model; verify no current field, setting, or phrase refers to backup age, stale thresholds, scheduling, or freshness.
- [x] 7.8 Run focused status, settings, locking, repository, applied-registry, reconciliation, JSON/porcelain, and dependency tests; verify the full status object matches the panel consumer fixture.

## 8. Remove Scheduler And Rebuild The Panel Around Loadouts

- [x] 8.1 Remove backup scheduler/service scripts, manifest registration, timers, settings, and installer/remover hooks; verify install, update, and removal manage only services still required by the Loadout panel/product.
- [x] 8.2 Rework `Service.qml` to request only documented loadout status, repository, catalog, lifecycle, resource, and Ress migration results; verify malformed results are discarded and no QML reads Git or Montage state/config files directly.
- [x] 8.3 Rework `Model.js` around Libraries, Compose/Share, Applied Loadouts, and the loadout attention classifications; verify model tests cover every summary state, per-cause detail, active marker ownership, and valid empty state.
- [x] 8.4 Rebuild `Panel.qml` navigation and actions as Libraries, Compose/Share, and Applied Loadouts; verify Backup, history, labels, retention, restore, secrets, scheduling, vault type selection, and export controls are absent from keyboard and pointer paths.
- [x] 8.5 Route divergent synchronization and optional confirmed Ress import to interactive terminal flows while keeping previews visible; verify the panel does not force resolution, publish without confirmation, or mutate source/destination itself.
- [x] 8.6 Replace bar backup freshness with loadout attention and active/partial/failed/unavailable states; verify bar fixtures and rendered screenshots distinguish the states without age or stale language.
- [x] 8.7 Update panel principles, CLI integration, keyboard workflow, settings, and status-language documentation in the same change; verify all controls and shortcuts described exist in rendered QML and all state semantics point to the CLI contract.
- [x] 8.8 Run QML syntax/model/consumer-boundary tests and record rendered-panel/keyboard checks as fresh-VM evidence where automation cannot prove layout; verify no unexecuted visual check is marked passed.

## 9. Reconcile Contracts, Architecture, Workflows, And Release Surfaces

- [x] 9.1 Rewrite vision and principles around the standalone Loadout lifecycle, constrained portable artifacts, consent, preservation, local ownership, and import-only Ress migration; verify they describe direction and link to specs/contracts rather than claiming unsupported implementation detail.
- [x] 9.2 Retain and update loadout repository/profile/applied-registry/CLI contracts, remove current vault/restore/secret/general-port contracts, and repair `docs/index.md`; verify all internal links resolve and exact formats have one authoritative contract.
- [x] 9.3 Rewrite system overview, application identity, module architecture, and migration architecture for the reduced dependency graph and trust boundaries; verify diagrams match `bin/mntg`, `tests/module-dependencies.tsv`, and structural checks.
- [x] 9.4 Retain and update compose/share/apply/lifecycle and repository-sync workflows, add the focused Ress loadout migration journey, and remove backup/restore/encrypted-secret/general-port journeys; verify documented commands match `mntg --help` and focused command tests.
- [x] 9.5 Reconcile testing strategy and fresh-machine validation with loadout-only automated, real-tool, network, rendered-panel, and clean-VM evidence; verify backup-only checks are removed and historical logs are not presented as current evidence.
- [x] 9.6 Rewrite README, website, media inventory/current captures, marketplace metadata, plugin copy, and release notes to remove backup promises and depict the three Loadout panel surfaces; verify repository-wide current-surface searches find no unapproved backup wording or imagery.
- [x] 9.7 Review every delta capability against final code/tests and record any real-machine-only validation gap without weakening the requirement; verify `openspec validate make-montage-loadout-only --type change --strict` passes.

## 10. Remove Obsolete Evidence And Perform Full Validation

- [x] 10.1 Delete backup/vault/restore/secret/scheduler/export/history-only cases, fixtures, stubs, mutation targets, static entrypoints, and dependency-map rows only after their Loadout replacements pass; verify no retained test imports a deleted asset and the deletion checklist is fully dispositioned.
- [x] 10.2 Review repository-wide `backup`, `restore`, `vault`, `retention`, `freshness`, `scheduler`, `age`, and Ress export/history matches; verify each remainder is a tested refusal, the legacy branch name, an active-change migration/deletion record, or explicitly historical archive material.
- [x] 10.3 Run all relevant focused test fragments after the final deletions, including command, AUR, loadout, repository, transaction, sync, Ress migration, status, QML, URL credential, untrusted input, and structure cases; verify every fragment passes from the loadout-only source tree.
- [x] 10.4 Run `./tests/run.sh`, `./tests/mutate.sh`, and `./tests/check-structure.sh .`; verify the complete automated suite passes, every mutation is killed, and the reviewed module graph has no deleted or reverse dependency.
- [x] 10.5 Run `openspec validate --all --strict`, inspect `git diff --check`, and review the explicit deletion/documentation/test inventories against the final diff; verify the change is internally consistent and contains no product implementation outside the accepted scope.
- [x] 10.6 Execute or explicitly defer the disposable-real-tool and fresh-Omarchy checks for real Git synchronization, credential helpers/SSH agents, package/AUR operations, plugin/theme effects, side-by-side Ress isolation, install/update/remove, and rendered keyboard panel behavior; verify each result records environment, versions, date, commit, observation, and cleanup without promoting a deferral to a pass.

## Workflow follow-up

- Review and approve the proposal, design, delta specs, deletion inventory, documentation plan, and test migration plan before implementation begins.
- After every tracked task is complete and evidence has been reviewed, archive `make-montage-loadout-only` through the OpenSpec archive workflow so the delta specs become main truth and retired capability requirements are removed.
- Run `openspec validate --all --strict` again after archive and verify the main spec set contains the new Loadout capabilities without empty or stale Backup/Restore capability containers.
