# Design

## Context

See [proposal.md](proposal.md) for the product decision. The current CLI is one Bash process: `bin/mntg` sources core, repository, machine, vault, loadout, and port modules before dispatch. Loadout modules do not depend on vault formats, but several application seams still combine both domains:

- `lib/montage/vault/commands.sh` owns general commands (`status`, `set`, `doctor`, and `link`) as well as vault-only commands.
- `lib/montage/core.sh` owns both neutral process machinery and backup-only configuration, paths, constants, and status concepts.
- `lib/montage/repository/` supports both `loadouts` and `vault` envelopes and configured entries.
- `lib/montage/port/` is a bidirectional, multi-artifact conversion framework even though only Ress loadout import remains useful.
- `Panel.qml`, `Service.qml`, and `Model.js` consume combined backup and loadout state.
- Several tests protect loadout safety through cases whose names or fixtures also cover backup behavior.

The CLI remains the sole authority for inspection, mutation, persistent state, and consumer output. The panel must continue to consume CLI results instead of interpreting Git, profiles, registries, or machine state. Existing user-owned vault repositories are outside the active product after their registry entries are retired and must never be used as migration scratch space or cleanup targets.

The active documentation still describes the combined product. During implementation, OpenSpec defines the intended observable behavior; contracts, architecture, panel language, workflows, tests, README, site, media, marketplace, and release material must be reconciled without describing this proposal as shipped before automated evidence exists.

## Goals / Non-Goals

**Goals:**

- Produce one loadout-only dependency graph in which no active entrypoint sources, dispatches, documents, or tests vault behavior.
- Preserve the full Loadout lifecycle and its safety properties while moving surviving guarantees out of mixed capabilities and tests before deletion.
- Give supported schema-1 mixed repository registries one deterministic, observable, idempotent transition to a loadout-only active registry.
- Reduce Ress interoperability to one contained, import-only legacy profile boundary.
- Make status and panel presentation a faithful summary of loadout health, repository attention, and operations.
- Leave a deletion inventory that can be checked mechanically, rather than treating hidden or unreachable backup code as an acceptable result.

**Non-Goals:**

- Keeping hidden aliases, compatibility dispatch, feature flags, dormant vault modules, or a second recovery application.
- Deleting, rewriting, synchronizing, or adopting any retired user-owned vault repository.
- Changing schema-version-1 native loadout repository envelopes or broadening portable `profile.json`.
- Redesigning Loadout resource semantics beyond refactors needed to preserve current behavior and remove vault coupling.
- Automatically contacting remotes during ordinary status refresh.
- Treating the legacy branch as a runtime dependency or migrating active work onto it.

## Decisions

### 1. Cut the product at domain ownership, not at visibility

The active source list and dispatch table will contain only core/safety, loadout-only repository infrastructure, neutral machine helpers, loadout modules, a focused Ress migration module, and relocated application commands. Vault code is deleted after every surviving caller has moved. No build flag, deprecated command alias, hidden JSON field, or ignored panel route will keep backup behavior reachable.

The final dependency direction is:

```text
bin/mntg
  -> core + safety
  -> repository (loadout-only registry/envelope/reader/transaction/sync/commands)
  -> machine/packages
  -> loadout (profile/registry/resources/planning/share/apply/lifecycle)
  -> migration/ress-v1-loadout
  -> application commands (status/set/doctor/link)

panel -> documented mntg JSON/porcelain only
```

The neutral transaction and reader code remains because loadout libraries require contained Git reads, atomic item publication, stable identity, recovery journals, and synchronization. Domain branches and parameters that exist only for vault payloads or history are removed.

Alternative considered: leave vault modules in place but stop advertising their commands. This was rejected because every sourced module remains part of startup and maintenance, hidden dispatch remains compatibility behavior, and backup concepts would continue to shape core and repository contracts.

### 2. Relocate general commands before deleting the vault layer

`status`, `set`, `doctor`, and `link` move from `vault/commands.sh` into a neutral application-command module (or equivalently narrow owner selected during implementation). Their behavior is rewritten around the loadout product:

- `status` aggregates validated applied-loadout, repository, synchronization evidence already available locally, and operation state.
- `set` accepts only settings still owned by the product; initially `AUR` is the required setting.
- `doctor` checks loadout runtime dependencies and configuration, not `age`, vault privacy, backup paths, restore tools, or scheduling.
- `link` continues to manage only Montage's owned `mntg` link and refuses conflicting ownership.

`machine/packages.sh` remains neutral and continues to own installed-package observation, repository/AUR classification, explicit AUR decisions, and package operations. Core retains output, bounded temporary paths, locking, cleanup, configuration serialization, and running-marker ownership, but loses backup constants, categories, vault defaults, and backup settings.

Alternative considered: move these functions into `loadout/lifecycle.sh`. This was rejected because PATH ownership, configuration, and environment diagnostics are application concerns, not applied-loadout state transitions.

### 3. Use registry schema 2 to make the one-time boundary enforceable

The configured-repository registry, not the native repository envelope, advances from schema 1 to schema 2. Schema 2 retains the current entry shape to minimize churn, but requires every entry's `type` to be exactly `loadouts`. New empty registries are schema 2. Native loadout repositories remain schema 1 with fixed `repositoryType: "loadouts"` as required by the repository-format delta.

On the first read of a schema-1 registry, the CLI performs this algorithm under the configuration lock:

1. Reread the exact source after acquiring the lock; if another process already installed schema 2, return a no-op result.
2. Validate the schema-1 document structurally, including unique names and credential-free remotes.
3. Validate each retained loadout entry's selector, canonical non-symlink path, expected id, loadout envelope, and remote using current rules. A bad retained entry fails the whole migration and names that entry; no replacement is installed.
4. Classify vault entries by their validated registry type without opening, fetching, initializing, or otherwise touching their paths.
5. Create a mode-0600, non-overwritten pre-migration copy beside the registry so rollback can recover the exact configured entry set. This copy is inert data and is never read by normal runtime.
6. Build schema 2 from the loadout entries, preserving name, canonical path, id, and sanitized remote, preserving deterministic name order, and incrementing the revision exactly once.
7. Validate the complete candidate with the schema-2 loadout-only validator and atomically replace `repositories.json`.
8. Record and return a migration result containing the prior/new schema and the names of retired entries. Human commands surface a concise notice; JSON and porcelain commands include the result within their one valid protocol response rather than writing stray stdout.

Rerunning against schema 2 performs no write and yields the same logical registry. A hand-edited `type: "vault"` in schema 2 is invalid rather than being treated as another migration input. This distinction is why an in-place schema-1 filter without a version marker was rejected: it could not tell a completed migration from a later attempt to reintroduce vault configuration.

The pre-migration copy contains configuration references only; actual repositories remain unchanged. Removing a repository entry continues to mean removing configuration, never filesystem data.

Alternative considered: require a dedicated interactive migration command. This was rejected because panel/status startup must handle supported installed state deterministically, and this migration removes no user repository data. Observability and an exact rollback copy provide the necessary explicitness without leaving the application unusable until a separate command is run.

### 4. Keep native repository mechanics but make their types loadout-only

Repository initialization, configuration, validation, queries, item lookup, transactions, and synchronization stop accepting a kind argument from users or callers. The repository envelope validator supports only schema-1 `montage-repository` documents whose `repositoryType` is `loadouts` and whose fields match the loadout envelope exactly. Vault envelopes are rejected before payload or Git-history inspection.

Generic reader and transaction functions remain only where a loadout caller uses them. Historical selection remains available where exact loadout provenance or update planning requires an exact commit; vault backup history, labels, retention, lineage, private-visibility policy, and payload validation are removed.

Alternative considered: remove the `repositoryType` field from loadout envelopes immediately. This was rejected as unrelated format churn; fixing the accepted value provides the loadout-only boundary without rewriting existing libraries.

### 5. Replace the port framework with a focused Ress loadout migration boundary

The remaining interoperability surface is logically one adapter and one direction. Implementation may retain small reusable staging/report helpers, but it will not retain a public format registry, export path, history traversal, vault translation, or a framework sized for hypothetical formats.

The focused flow is:

1. Identify a regular, non-symlink Ress v1 `profile.json` contained by the supplied source.
2. Validate the supported version and declarative profile fields before planning a destination.
3. Produce the same human/JSON decision record used by live import, including representational losses and Ress/Montage self-plugin handling.
4. Require one configured loadout library and one stable loadout id.
5. Stage a single translated native profile away from source and destination, validate it with the native profile validator, preview the exact publication, and require confirmation.
6. Publish the selected item through the loadout repository transaction boundary, preserving siblings, identity, remote, and clean-tree rules, and commit only a content change.
7. Never import Ress config, remote ownership, locks, Git history, applied state, claims, cleanup authority, credentials, keys, machine identity, or vault material.

The Ress source is always read-only. The destination gains only a portable definition; native provenance and cleanup authority begin later, if and when `mntg apply` succeeds.

Alternative considered: keep the generic bidirectional framework for future formats. This was rejected because the product has one frozen legacy input, and the framework's export/history/vault abstractions create more invalid states and test burden than the remaining boundary needs.

### 6. Define status as a precedence-ordered loadout attention projection

`mntg status` computes detail first and then a stable summary. It does not repair, update, synchronize, or fetch. For an absent or schema-2 configured-repository registry, it also performs no write. A supported schema-1 registry remains the single exception: the first status or panel read runs Decision 3's locked atomic migration before projecting attention, reports that migration through the normal result, and never touches a configured repository path. The summary uses this precedence so a consumer does not hide higher-severity evidence:

1. `operation-active` when the live lock owner has a valid running marker;
2. `operation-partial-or-failed` when the latest authoritative loadout operation records an incomplete or failed outcome and no operation is active;
3. `unavailable-or-invalid` when required registry, applied-state, repository, or operation evidence cannot be validated;
4. `repository-attention` for invalid/unavailable configured libraries or locally established remote-ahead/divergent evidence requiring a decision;
5. `drifted` for incompatible current resource evidence;
6. `repair-needed` for missing or ordinarily repairable tracked resources;
7. `update-available` only when an explicit resolution/update preview has established changed content for the same repository/loadout identity;
8. `healthy` when all available applied claims are satisfied and no attention remains.

The JSON result also carries per-loadout and per-repository details so the panel can identify the cause. Empty valid state is healthy with zero applied loadouts; malformed optional state is not silently treated as empty. Backup timestamps, age, stale thresholds, schedules, and freshness fields do not exist.

Alternative considered: preserve a generic `stale` state and reinterpret it for loadouts. This was rejected because the old term encodes backup age, while drift, repair, update, and repository decisions have different evidence and actions.

### 7. Preserve Loadout safety by extracting ownership, not copying mixed code wholesale

Before deleting a mixed test or capability, its surviving assertion is assigned to the loadout owner:

| Surviving guarantee | Final owner | Evidence destination |
|---|---|---|
| AUR has separate consent and declined work remains pending | `loadout-execution-consent`; machine/loadout planning | focused apply/repair AUR cases |
| Application is additive; remove uses recorded claims only | `loadout-preservation`; loadout registry/resources/lifecycle | apply, claims, pre-existing/shared/changed/unverifiable removal cases |
| URLs are stored and emitted without userinfo | loadout sharing/repositories; safety validators | sharing, registry, sync, and migration URL cases |
| Control files and tree reads are contained and symlink-safe | untrusted artifact reading; safety/repository/migration readers | hostile loadout/repository/Ress cases |
| Source, repository, loadout, and commit identity are exact | loadout repositories/profile/registry | identity, historical read, update, and migration cases |
| `mntg` link and dispatch ownership are exact | application commands and entrypoint | startup, link ownership, and removed-command cases |
| JSON/porcelain remains parseable and stable | CLI consumer protocol | status/repository/share/lifecycle/resource/migration protocol cases |
| Repository writes are locked, atomic, recoverable, and content-sensitive | repository transaction | loadout transaction, recovery, and concurrency cases |
| Plugin/theme refs are pinned and provenance is preserved | profile/planning/resources | apply/check/repair/update round-trip cases |
| Applied state grants only recorded cleanup authority | loadout registry/lifecycle | provenance, claims, and safe cleanup cases |

Tests are renamed or split before backup assertions and fixtures are removed. Mutation targets and the reviewed dependency map move with production ownership in the same phase, so a passing suite cannot result from silently dropping a detector.

Alternative considered: delete every test whose filename mentions backup or a mixed capability, then rebuild coverage afterward. This was rejected because it creates an unprotected interval exactly where shared safety regressions are most likely.

### 8. Keep persistent user data unless the product owns an exact obsolete state file

Implementation removes writers and readers for backup-only configuration keys and Montage-owned operational files such as backup freshness stamps, restore progress, backup findings, scheduler state, and obsolete service metadata. It does not recursively delete the Montage state/config roots, because they also contain loadout registries, repository locks/journals, and configuration.

Obsolete keys in the line-oriented config are ignored on read and omitted on the next loadout-owned save rather than triggering backup compatibility code. Obsolete state files may be removed only by exact, validated path after all readers are gone; absence is a successful no-op. Vault paths and contents are never cleanup targets. The migration's inert pre-schema-2 registry copy is retained for rollback and may be removed only by an explicit future user-facing decision outside this change.

Alternative considered: eagerly clean every legacy Montage path. This was rejected because ownership is mixed, vault paths are user-owned, and broad cleanup would violate the preservation boundary.

### 9. Rebuild the panel around three CLI-backed surfaces

The panel presents Libraries, Compose/Share, and Applied Loadouts. Libraries consumes repository and sync queries; Compose/Share consumes the CLI catalog and publishes an explicitly selected library item; Applied Loadouts consumes lifecycle, resource, and attention results. Risky sync resolution and confirmed Ress import use an interactive terminal handoff. The bar displays the loadout attention classification and live operation state.

`Service.qml` continues to execute the CLI and parse documented results. `Model.js` maps only the new protocol to view state. Neither reads `repositories.json`, Git, profiles, applied registry files, or running state directly. Backup tab routes, history/restore/retention controls, scheduler toggles, freshness timers, and vault settings are deleted rather than hidden.

The plugin manifest removes backup scheduler/service registration and backup-oriented copy. It retains only services needed by panel lifecycle and the loadout product.

Alternative considered: keep the four-tab layout and repurpose Backup as Libraries. This was rejected because retained routes, models, and labels would obscure the actual product boundary and preserve dead backup assumptions.

### 10. Reconcile documentation by authority layer

Implementation updates each layer for its own purpose:

- Vision and principles describe portable Loadouts, additive reconstruction, consent, local ownership, and the narrowed Ress migration boundary.
- Main specs receive these deltas during archive; retired capabilities have no surviving requirements, while moved guarantees live under loadout-specific capabilities.
- Contracts retain repository envelope, loadout profile, applied registry, and loadout-only CLI protocol; vault, restore, secret-transport, and general port contracts are removed or archived as historical material.
- Architecture documents the reduced module graph, loadout-only state, trust boundaries, and focused migration path.
- Panel documents attention language, the three surfaces, CLI integration, keyboard behavior, and settings.
- Workflows cover compose/share, inspect/apply, check/repair/update/remove, repository sync, and Ress loadout migration only.
- Testing documents automated versus disposable-real-tool versus fresh-VM evidence without claiming unexecuted checks.
- README, site, media inventory, marketplace, and release copy remove backup promises and screenshots.

Links are checked after deletions so no current page points to retired contracts or workflows. Historical branch references explain where the former product lives but do not function as compatibility instructions.

## Trust Boundaries

### Execution

A portable profile remains declarative and cannot carry commands, arbitrary files, services, secrets, or implicit cleanup instructions. AUR builds remain separately consented; `--yes` does not answer that decision. Declined AUR work remains pending and machine readable. Removal executes only actions justified by native recorded claims and current live guards.

### Persistence

Registry migration and repository publication use distinct locks, whole-document/tree validation, bounded same-filesystem staging, atomic replacement, and recovery journals where applicable. Invalid retained entries abort without a partial schema-2 registry. The registry migration never opens a vault path, and loadout removal never infers ownership from absence in a profile.

### Confidentiality and untrusted input

Configured remotes, profile sources, and consumer output remain credential-free. Loadout envelopes, profiles, registries, and Ress inputs must be regular non-symlink files contained under validated roots. Unsupported versions and hostile JSON are rejected before mutation. Removing encrypted-secret backup transport does not create another plaintext secret path.

### Network

Ordinary status is local and cannot claim an update without prior explicit resolution evidence. Repository sync remains an explicit fetch/classify operation; pull is fast-forward-only, push is non-forced, and divergence requires a user decision. Ress migration reads the supplied source and does not adopt its remotes.

### Consumer

JSON commands emit one complete object; porcelain records remain documented and ordered. Human migration notices go to the human result path, never as stray protocol text. The panel discards malformed CLI results and does not reconstruct a healthy state from missing data.

## Explicit Deletion Inventory

The implementation is complete only when the following categories are absent from active product sources, routing, protocol, UI, docs, and tests:

- **Commands:** `backup`, backup history/show/label/unlabel/retain, `restore`, backup-oriented `verify`, `scan`, `enable-units`, `diff`, vault `init`, `secrets`, Ress vault import/history, and every Ress export.
- **Modules:** `lib/montage/vault/`; backup/restore/verify branches in core and repository code; `port/export.sh`; vault/history paths in port import/inspect; generic adapter machinery not used by focused Ress loadout migration.
- **Repository behavior:** vault initialization, validation, configuration, list/show/sync, machine lineage, backup commits, labels, retention, private-vault visibility, and vault payload/history readers.
- **Configuration and state:** `VAULT`, `REMOTE` where vault-owned, `AUTO_BACKUP`, `AUTO_INTERVAL_HOURS`, `AUTO_PUSH`, `INCLUDE_*`, `SECRETS_*`, `PROFILE_URL`, `ENABLE_UNITS`, `SECRET_SCAN`, `CAPTURE_AUTOSTART`, vault defaults/categories, backup stamps/findings, restore progress/failures/first-contact/unit decisions, and scheduler state.
- **Dependencies and services:** `age`, backup-only `rsync` use, scheduler commands/timers/services, and backup-only Git/history plumbing. A dependency is removed from packaging only after all surviving loadout callers are checked.
- **Panel:** Backup tab, backup age/freshness, history, labels, retention, restore, secret transport, schedule, vault repository selection, and general port/export controls.
- **Protocols:** backup/vault/restore/verification/retention/scheduler records and JSON fields, plus general bidirectional port envelopes not needed by Ress loadout migration.
- **Documentation:** vault/restore/secret/general-port contracts, backup and encrypted-secret workflows, backup architecture/status/settings language, backup README/site/marketplace/release claims, and current media that depicts the removed product.
- **Specifications:** all requirements in `vault-capture`, `vault-repositories`, and `resumable-restore`; mixed capability requirements explicitly removed by this change; retired capability containers once the deltas are archived and no requirement remains.
- **Tests and fixtures:** backup/vault/restore/secret/scheduler/export/history-only cases, stubs, fixtures, mutation targets, dependency-map rows, and static entrypoints, but only after the Loadout assertions listed in Decision 7 have focused replacements.

Search-based checks supplement, but do not replace, behavior tests. Remaining occurrences of words such as `vault`, `backup`, or `restore` must be either the legacy branch name, an explicit refusal/migration test, or historical archive material; each exception is reviewed rather than globally allowlisted.

## Risks / Trade-offs

- **[A mixed registry contains a damaged loadout entry]** → Fail the migration atomically, name the entry, preserve the original registry, and require explicit correction; never silently drop a loadout entry to make migration succeed.
- **[An old binary cannot read schema-2 registry state during rollback]** → Preserve an exact mode-0600 schema-1 copy before replacement and document the manual rollback step; never overwrite that copy on retries.
- **[Automatic migration pollutes JSON or porcelain]** → Return migration facts inside the command's normal versioned result and keep stdout to one protocol document/record stream.
- **[Removing vault code also removes general commands or helpers]** → Relocate commands and prove their startup/link/config/status behavior before deleting `lib/montage/vault/`; keep neutral machine helpers covered independently.
- **[Mixed tests disappear with their loadout guarantees]** → Extract and run focused replacement cases first, then update mutation mappings and only then delete backup cases and fixtures.
- **[Simplifying the port framework weakens containment or transaction safety]** → Retain the proven safety primitives actually used by one-item migration and add focused hostile-source, preview parity, atomic publication, and source-preservation cases before deleting framework tests.
- **[Status becomes slow or network-dependent]** → Use validated local state and cached results from explicit sync/update resolution only; prohibit fetch and, after the one-time schema-1 registry transition, mutation during ordinary refresh.
- **[Attention precedence hides useful detail]** → Keep one summary for the bar while returning all per-loadout/repository causes in the CLI result and panel detail.
- **[Obsolete files are confused with user-owned data]** → Delete only exact Montage-owned operational paths after ownership review; leave vault repositories and the pre-migration registry copy untouched.
- **[Documentation claims outrun evidence]** → Mark the active change as proposed until implementation and automated validation pass; classify real-machine, rendered-panel, network, and clean-VM checks accurately.
- **[Large deletion causes review blind spots]** → Follow phased commits with focused tests and deletion inventories; do not combine safety extraction and source deletion in one opaque step.

## Migration Plan

1. Establish the loadout-only specs, command/protocol inventory, dependency target, deletion inventory, and expected status vocabulary. Do not change runtime claims yet.
2. Extract every surviving Loadout assertion from mixed tests; add focused protocol, preservation, consent, containment, identity, transaction, pinning, and ownership cases plus corresponding mutation detectors.
3. Replace broad Ress portability with inspect and one-item loadout import. Prove source immutability, schema/version refusal, loss/self-plugin decisions, preview parity, destination atomicity, and absence of imported authority before removing export, vault, history, and generic-framework paths.
4. Add schema-2 loadout-only configured registries and the locked schema-1 migration. Prove deterministic ordering, revision behavior, retry/no-op behavior, exact backup copy, invalid-retained-entry rollback, untouched vault paths, credential-free remotes, and post-migration vault rejection. Then remove vault branches from repository operations.
5. Relocate and narrow `status`, `set`, `doctor`, and `link`; preserve `machine/packages.sh` and other demonstrated neutral loadout helpers. Prove source-time purity, symlinked/relocated startup, link ownership, AUR setting behavior, and JSON/porcelain validity.
6. Remove vault dispatch, source-list entries, modules, commands, and protocol records. Confirm removed commands fail as unknown and no loadout module has acquired a vault dependency.
7. Remove backup configuration keys, constants, dependencies, and exact obsolete operational state handling. Implement precedence-ordered loadout attention and prove status is local, truthful under malformed optional state, and non-mutating outside Decision 3's first-read registry migration.
8. Remove scheduler/service wiring and rebuild the panel/bar around Libraries, Compose/Share, and Applied Loadouts. Verify CLI-only authority, terminal handoffs, keyboard navigation, malformed-result handling, rendered layout, and absence of backup language.
9. Reconcile main specs through the OpenSpec archive workflow and update contracts, architecture, panel docs, workflows, testing guidance, README, site, media, marketplace, and release surfaces according to their authority. Validate links and current-versus-historical wording.
10. Remove obsolete backup fixtures, stubs, tests, mutation targets, static entrypoints, and dependency-map rows after their replacements are green. Run focused cases throughout, then `./tests/run.sh`, `./tests/mutate.sh`, `./tests/check-structure.sh .`, and `openspec validate --all --strict`. Record disposable-real-tool, rendered-panel, network, and fresh-VM checks separately where the sandbox cannot prove them.

### Rollback

Code rollback uses the commit immediately before this change or the preserved `legacy-montage-backup-and-loadout` branch for the historical combined product; the active implementation does not include a compatibility switch. Before running an older combined binary against an installation whose registry migrated to schema 2, the operator restores the preserved pre-migration schema-1 registry copy under the configuration lock. No repository content rollback is required because migration never modifies a loadout or vault repository. Loadout repository commits created by normal post-migration use remain ordinary user-owned Git history and are not automatically rewritten during rollback.
