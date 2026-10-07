# Tasks

## 1. Application Identity And Namespace Isolation

- [x] 1.1 Rename `bin/ress`, `lib/ress/`, active shell symbols, module maps, and test harness entrypoints to `mntg` and `lib/montage/`; verify `./tests/run.sh cli-modules` and `./tests/run.sh structure` pass with no Montage runtime dependency on the old entrypoint.
- [x] 1.2 Change the plugin manifest, QML module, service, panel, and IPC identities to `tombychowski.montage`; add side-by-side identity fixtures and verify `./tests/run.sh qml` and `./tests/run.sh structure` prove Ress and Montage targets are distinct.
- [x] 1.3 Move configuration, data, operational state, locks, restore progress, and applied-loadout registry defaults into Montage XDG roots; add isolation cases and verify `./tests/run.sh settings` and `./tests/run.sh status-config` perform no ordinary read or write below Ress roots.
- [x] 1.4 Implement guarded creation and removal of the owned `~/.local/bin/mntg` link, including refusal to replace an unrelated path and non-interference with `ress` and ImageMagick `montage`; verify focused first-contact and collision tests pass.
- [x] 1.5 Rename active replacement suffixes and self-exclusions to `.montage-bak` and Montage-owned paths while retaining Ress spellings only in compatibility fixtures; verify focused backup and structure tests cover exclusion and no recursive capture.
- [x] 1.6 Update the CLI architecture, installation, identity, and coexistence documentation for `mntg`, the new plugin id, IPC target, and XDG roots; verify documented commands match `mntg --help` and the documentation link checker or repository structure checks pass.

## 2. Repository Foundation And Contracts

- [x] 2.1 Define exact `montage.json` envelope contracts for loadout and vault repositories, including integer schema versions, repository kinds, stable ids, field bounds, and canonical examples; implement validators and verify schema, future-version, hostile-id, and wrong-kind tests pass.
- [x] 2.2 Implement the configured repository registry with named entries, validated absolute paths, expected repository ids, repository kinds, and sanitized optional remotes; verify serialized configuration tests cover stale-id replacement and concurrent updates.
- [x] 2.3 Add shared repository locks, same-filesystem staging, atomic publication or recovery journals, clean-worktree checks, and content-changing Git commit helpers; verify interruption, contention, no-op, and failed-validation tests leave repositories recoverable.
- [x] 2.4 Add contained regular-file, bounded-ref, stable-id, and isolated historical-tree readers for native repositories; verify `./tests/run.sh untrusted-controls` covers symlinks, traversal, hostile refs, and escaping directory links.
- [x] 2.5 Add human and versioned JSON repository list, show, validation, and configuration commands used by the panel; verify each JSON command emits exactly one parseable result and human mode remains readable.
- [x] 2.6 Document repository ownership and module boundaries in the contracts and CLI architecture without duplicating observable requirements; verify all new contract paths are linked from `docs/index.md`.

## 3. Multi-Loadout Repositories

- [x] 3.1 Implement loadout-repository initialization and discovery at `loadouts/<stable-id>/profile.json`, with immutable bounded ids and mutable display metadata; verify multi-item list, rename, invalid-entry, and identity-stability tests pass.
- [x] 3.2 Retain schema-version-1 `profile.json` with `kind: "omarchy-loadout"` as the portable leaf and support contained standalone leaves; verify current hostile-profile, schema, command-field, credential, and round-trip tests pass under `mntg`.
- [x] 3.3 Change unfiltered and selective sharing to create or update one explicitly selected repository loadout through staged validation and one content-changing commit; verify share-compose tests cover preservation of sibling loadouts, stale selections, empty selection, theme conflicts, and withdrawal acknowledgements.
- [x] 3.4 Remove native Ress short-link resolution and generate canonical credential-free repository instructions using an explicit `--loadout <stable-id>` selector; verify URL and generated-instruction tests contain no Ress shortener dependency or embedded credentials.
- [x] 3.5 Resolve remote and local repository sources to an exact commit before apply preview, and persist repository id, loadout id, commit, digest, and validated snapshot after confirmation; verify apply and loadout-identity tests reject selector drift and silent profile replacement.
- [x] 3.6 Update applied-loadout provenance, query, update, repair, and removal code to use Montage ownership language without adopting imported Ress claims; verify focused registry, claim, update, repair, removal, and historical-ownership tests pass.
- [x] 3.7 Document loadout repository layout, stable selectors, portable-leaf compatibility, sharing, application, and applied-state contracts and workflows; verify every example uses `mntg` and distinguishes library items from machine-local applied loadouts.

## 4. Vault Repositories And Historical Restore

- [x] 4.1 Implement vault initialization with one machine lineage, stable repository identity, root `montage.json`, and current `backup.json`; verify vault-format tests reject wrong kinds, changed identities, malformed schemas, and mixed loadout content.
- [x] 4.2 Refactor backup to stage and validate the complete snapshot, pass the credential gate, publish atomically, and create exactly one commit only when content changes; verify backup, secret-scan, empty-change, and interrupted-publication tests pass.
- [x] 4.3 Implement human and JSON backup list and show commands that inspect exact commits without changing the checkout; verify history tests report valid metadata and reject commits with missing, symlinked, future, or escaping controls.
- [x] 4.4 Bind verify, preview, restore confirmation, dry run, and resume progress to repository id plus resolved backup commit; verify restore tests reject mutable-selector drift and never reuse progress across repository or commit changes.
- [x] 4.5 Implement validated unique backup labels and previewed local retention operations, including explicit reporting when resulting history diverges from a published remote; verify label resolution, protected history, cancellation, confirmed pruning, and divergence tests pass.
- [x] 4.6 Exclude Montage configuration, state, locks, repositories, CLI links, and `.montage-bak` files from capture and reporting recursion; verify backup tests cover configured repositories nested below supported capture roots.
- [x] 4.7 Document the vault envelope, backup manifest, commit identity, label, retention, restore-resume, and private-storage contracts and workflows; verify examples select exact commits or labels and explain retention's remote-divergence consequence.

## 5. Conservative Git Synchronization

- [x] 5.1 Implement credential-free remote canonicalization and reject or redact URL user information before configuration, output, commits, or generated instructions; verify `./tests/run.sh url-credentials` covers loadout and vault remotes.
- [x] 5.2 Implement fetch-based equal, local-ahead, remote-ahead, and divergent classification without changing repository content; verify deterministic Git-fixture tests cover every relationship and authentication or fetch failure.
- [x] 5.3 Implement only history-preserving fast-forward pull and non-forced push actions, with preview and decision-required results for divergence; verify fake-remote tests prove no force option, silent reset, automatic content merge, or false success occurs.
- [x] 5.4 Add vault visibility inspection when safely available and require confirmation for a known-public GitHub remote while treating unknown visibility as unknown; verify mocked public, private, unavailable, and unauthenticated cases.
- [x] 5.5 Expose versioned human, JSON, and porcelain synchronization results for both repository kinds; verify protocol tests cover previews, successful no-op/fetch/push, divergence, credential refusal, and partial failure.
- [x] 5.6 Document Git transport assumptions, credential-helper boundaries, public loadout versus private vault guidance, divergence resolution, and the no-force guarantee; verify no documentation tells users to place tokens in Montage configuration.

## 6. Ress V1 Port Adapter

- [x] 6.1 Freeze representative supported Ress v1 vault, loadout, legacy-manifest, suffix, plugin-entry, and history fixtures under the port test boundary; document the precise compatibility baseline and verify fixture validation does not call native Montage readers directly.
- [x] 6.2 Implement read-only Ress artifact inspection and dry-run planning with artifact type, version, source, destination, selected revisions, warnings, losses, and mutations in human and versioned JSON output; verify hostile, future-version, symlink, and no-write tests pass.
- [x] 6.3 Implement current Ress loadout import into a new stable item in a selected Montage loadout repository through staging and atomic publication; verify the source, siblings, remotes, and applied registry remain unchanged.
- [x] 6.4 Implement current Ress vault import into a fresh Montage vault repository with new history and no inherited remote; verify manifest/suffix translation, ciphertext handling, source preservation, and exclusion of Ress config, keys, locks, progress, and ownership state.
- [x] 6.5 Implement optional Ress vault history translation by isolated chronological revision validation and new Montage commits, with previewed compatible-subset selection; verify a bad middle revision publishes nothing by default and original hashes or remotes are never claimed as native.
- [x] 6.6 Implement export of one selected Montage loadout or backup to a separate validated Ress v1 staging directory; verify native commits and working trees are unchanged and non-empty destinations are not overwritten implicitly.
- [x] 6.7 Enforce itemized representational-loss consent, non-waivable safety and ownership refusals, and explicit Ress/Montage self-plugin decisions; verify general loss acceptance cannot bypass credential, containment, consent, private-key, or cleanup guarantees.
- [x] 6.8 Document import/export commands, current-snapshot default, optional history cost, loss matrix, encryption identity boundary, self-plugin handling, and manual copy fallback; verify every documented flow begins with inspection or dry run and uses separate paths.
- [x] 6.9 Extract format-neutral adapter dispatch, destination isolation, Git revision materialization, report projection, and exact loss-policy primitives from the Ress implementation; verify focused framework tests cover unsupported formats, generic reports, and non-waivable safety.
- [x] 6.10 Split Ress v1 detection, inspection, import, export, and command parsing into bounded adapter modules without changing the `mntg port ress` user workflow; verify all frozen Ress fixtures and port cases pass.
- [x] 6.11 Generalize the JSON and porcelain port contract to `montage-port-report` plus a stable `format` identifier, and update panel parsing and consumer tests without introducing artifact interpretation in QML.
- [x] 6.12 Document the port adapter contract, module ownership, future-format workflow, and Ress v1 boundary; verify structure checks enforce the format-neutral/adapter dependency direction.
- [x] 6.13 Extract one envelope-neutral, contained Git-object materializer from the native repository history reader and use it for port history; verify hostile paths, modes, links, and revisions are refused without archive extraction or checkout mutation.
- [x] 6.14 Add a literal adapter dispatch contract and generic context, then move inspection, report construction, destination planning, history iteration, and selection planning into shared port engine modules; verify Ress inspection behavior and unsupported-format refusal remain unchanged.
- [x] 6.15 Move loadout/vault import and loadout/backup export lifecycle orchestration—including dry run, decisions, confirmation, native selection, locks, repository setup, staging, validation sequencing, commits, publication, and result output—into shared engine modules with only translation and foreign-validation callbacks remaining in the Ress adapter; verify all Ress port cases pass.
- [x] 6.16 Reconcile architecture and testing documentation with the implemented engine boundary and add structural checks that format adapters cannot own confirmation, Git traversal, native repository transactions, staging, publication, or consumer output; verify the shared engine is materially larger than dispatch glue and strict OpenSpec validation passes.
- [x] 6.17 Remove unused port globals and arguments, collapse per-callback pass-through wrappers into one literal adapter callback matrix, initialize descriptor facts once, and move format-independent mutation planning out of the adapter; verify structure and port-framework tests prove unsupported callbacks fail closed without dynamic evaluation.
- [x] 6.18 Consolidate repeated shared refusal, decision, dry-run, result, and export-publication paths plus common port command parsing; return structured JSON for missing format decisions and refuse executable plans for recognized manifest-only sources; verify inspection, import, export, loss-safety, command-routing, JSON, and porcelain cases.
- [x] 6.19 Deduplicate Ress v1 runtime context, payload copying, plugin-decision/loss helpers, and portable-profile validation without weakening the frozen compatibility baseline; reconcile adapter architecture and testing documentation, then verify all focused port cases, `./tests/run.sh`, and `openspec validate --all --strict` pass.

## 7. CLI And Panel Consumer Integration

- [x] 7.1 Reconcile `mntg` help, status, verify, backup, restore, share, apply, applied-loadout, repository, history, sync, and Ress port routing with the final command contracts; verify command-dispatch tests cover valid and invalid subcommands without a Montage-owned `ress` or `montage` alias.
- [x] 7.2 Extend JSON and porcelain schemas with repository, loadout-item, backup-commit, sync, and port identities while keeping protocol stdout prose-free; verify `./tests/run.sh porcelain` and focused JSON cases parse exactly one documented result.
- [x] 7.3 Update the panel and service to invoke only `mntg` and consume CLI repository, history, share-catalog, sync, applied-loadout, and port results without inspecting Git or artifact files; verify QML structural tests reject direct repository parsing and old command paths.
- [x] 7.4 Add keyboard-accessible repository and loadout selection, selected-loadout composition, vault history inspection, and exact-backup restore launch surfaces; verify model and QML tests cover empty, invalid, loading, healthy, stale, divergent, and attention states.
- [x] 7.5 Add panel settings for Montage repository locations and sanitized remotes, explicitly excluding shared Ress directories; verify writes go through the configuration lock and a Ress path selected for migration is treated only as a port source.
- [x] 7.6 Route restore, destructive retention, divergent sync, loadout mutation, and Ress port publication through interactive terminals while leaving read-only previews in panel consumers; verify QML tests preserve confirmation, privilege, and AUR consent boundaries.
- [x] 7.7 Update panel-language, keyboard workflow, consumer-protocol, and settings documentation and capture required screenshot or real-machine evidence classifications; verify documented labels match QML strings and every panel state maps to a CLI result.

## 8. Independent Product And Release Documentation

- [x] 8.1 Reconcile README, vision, principles, active architecture, current workflows, testing guidance, and documentation index with Montage identity and the separate-product direction; verify an allowlisted search leaves Ress references only in portability, migration, historical changelog, and archived evidence contexts.
- [x] 8.2 Create the independent Montage marketplace and release metadata, repository/homepage links, install/update/remove instructions, and asset naming while leaving the published `resurrect` identity untouched; verify manifest validation and structure tests pass.
- [x] 8.3 Add a release migration guide mapping old commands and paths to Montage, explaining explicit porting, rollback, repository initialization, private vault remotes, and why `profile.json` remains portable; verify all commands execute as documented in the test harness or are marked real-machine-only.
- [x] 8.4 Update current site copy, screenshots, diagrams, and generated examples to Montage without rewriting historical records; verify media and link inventories contain no active Ress branding outside the documented compatibility boundary.
- [x] 8.5 Reconcile test strategy and fresh-machine validation checklists with side-by-side install, ImageMagick command coexistence, plugin independence, GitHub synchronization, public-vault warning, historical restore, and Ress port evidence; verify each non-automatable claim has an explicit environment and expected observation.

## 9. Integration Verification

- [x] 9.1 Run `./tests/run.sh` and fix all regressions; verify the final invocation completes with every automated case passing.
- [x] 9.2 Run `openspec validate --all --strict` and verify the repository's main specs and this change are structurally valid with no warnings or errors.
- [x] 9.3 Perform the documented active-source branding and path audit and verify only the allowlisted Ress port, migration, fixture, changelog, and archived-evidence references remain.
- [x] 9.4 Execute and record clean-Omarchy validation for separate Ress and Montage installation, panel rendering and keyboard use, independent update/removal, `mntg` link collision behavior, ImageMagick coexistence, private GitHub sync, divergence handling, and exact historical restore.
- [x] 9.5 Execute and record real-machine port validation on disposable copies of representative Ress v1 loadouts and vaults, including current and optional history paths; verify sources remain byte-for-byte or Git-status unchanged and exported staging copies are accepted by the supported Ress baseline.

## Workflow follow-up

- Review the implementation and validation evidence against this change.
- Sync the approved delta specs into the main specs, then archive the change through the repository's OpenSpec workflow.
- Verify the archived change and strict OpenSpec validation after the sync.
