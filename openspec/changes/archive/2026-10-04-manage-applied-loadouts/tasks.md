# Tasks

## 1. Registry Foundation And Trust Boundary

- [x] 1.1 Define the version-1 loadout registry schema, invariants, private state path, empty-state behavior, and canonical validation helpers in `bin/ress`; add focused tests for valid, missing, malformed, unsupported, dangling, duplicate, and hostile records and verify them with `./tests/run.sh loadout-registry`.
- [x] 1.2 Implement restrictive creation plus validated same-directory temporary-file and atomic-rename updates with monotonic revisions; test interrupted/stale writes and verify the registry is valid JSON, mode `0600`, and never partially replaced with `./tests/run.sh loadout-registry`.
- [x] 1.3 Extend the global operation lock to apply, update, repair, and removal while keeping dry runs mutation-free; add concurrent-operation and running-marker assertions and verify them with `./tests/run.sh loadout-lock`.
- [x] 1.4 Add operation and per-action planned/running/terminal journal states plus recovery classification for completed, absent, and ambiguous evidence; test seeded interruption windows and verify ambiguous actions become uncertain rather than pre-existing with `./tests/run.sh loadout-recovery`.
- [x] 1.5 Create `docs/contracts/loadout-registry.md` and update `docs/architecture/system-overview.md` with schema ownership, atomicity, privacy, trust, locking, exclusion from vault/share, and recovery boundaries; verify every documented path and state against the implementation and `./tests/run.sh loadout-registry`.

## 2. Resource Model, Identity, And Queries

- [x] 2.1 Implement normalized profile snapshots, canonical digesting, readable collision-safe local IDs, sanitized source persistence, and exact-reapply detection; test unknown-field/order normalization, credential stripping, duplicate digests, and ID collisions with `./tests/run.sh loadout-identity`.
- [x] 2.2 Implement canonical package, plugin, web-app, installed-theme, and active-theme identities plus compatible-definition comparison; test native/AUR name overlap and same-identity/different-definition conflicts with `./tests/run.sh loadout-resources`.
- [x] 2.3 Implement kind-specific inspection evidence for package presence, plugin/theme remote and commit plus local changes, web-app launcher semantics and attributable artifacts, and active-theme selection; verify present, missing, modified, conflicting, and unverifiable fixtures with `./tests/run.sh loadout-resources`.
- [x] 2.4 Implement claim creation and sharing while preserving first-observation and cleanup policy across later claims and repairs; test pre-existing, ress-introduced, shared, unknown, and protected-after-repair transitions with `./tests/run.sh loadout-claims`.
- [x] 2.5 Add `ress loadout list`, `ress loadout show`, `ress resource list`, and `ress resource show` human and JSON surfaces with optional stored content; verify stable structured identities, relationships, provenance, cleanup policy, and offline snapshot output with `./tests/run.sh loadout-query`.
- [x] 2.6 Extend `docs/contracts/cli-protocol.md` with the loadout/resource JSON shapes and compatibility rules, and update CLI help/README query examples; verify documented examples against `./tests/run.sh loadout-query` and assert porcelain/JSON stdout remains protocol-only with `./tests/run.sh porcelain`.

## 3. Tracked Apply And Explicit Update

- [x] 3.1 Refactor apply planning to inspect every normalized resource and classify install, pre-existing/protected, shared, conflicting, refused, and active-theme actions before confirmation; test complete previews and dry-run no-state behavior with `./tests/run.sh tracked-apply`.
- [x] 3.2 Persist a confirmed loadout and its baselines before mutation, record every resource outcome immediately, and register an all-present loadout without reinstalling resources; verify no-op, shared, mixed, and first-install cases with `./tests/run.sh tracked-apply`.
- [x] 3.3 Correct apply completion semantics so failed, deferred, conflicting, and uncertain claims remain visible and emit qualified porcelain outcomes rather than `DONE|ok`; verify repo failure, missing `yay`, declined AUR, plugin/web-app/theme failure, and interrupted actions with `./tests/run.sh tracked-apply` and `./tests/run.sh porcelain`.
- [x] 3.4 Add `ress loadout update ID [SOURCE]` with digest checks and a preview of added, retained, conflicting, and withdrawn claims; test that ordinary apply never replaces changed known-source content and verify confirmed/dry-run update behavior with `./tests/run.sh loadout-update`.
- [x] 3.5 Route withdrawn update claims through the same retention/removal planner used by loadout removal and leave unresolved withdrawals pending; test shared, protected, owned, and modified withdrawals with `./tests/run.sh loadout-update`.
- [x] 3.6 Update `docs/contracts/loadout-profile.md` and `docs/workflows/share-apply.md` for tracked no-op apply, local IDs, exact reapply, explicit update, conflicts, partial outcomes, and unchanged public schema version 1; verify every documented command with `./tests/run.sh tracked-apply` and `./tests/run.sh loadout-update`.

## 4. Drift Checking And Explicit Repair

- [x] 4.1 Add `ress loadout check [ID]` human and JSON output with aggregate exit status and structured per-resource health; test healthy, missing, modified, conflicting, protected, pending, and unverifiable states with `./tests/run.sh loadout-check`.
- [x] 4.2 Add a compact loadout count/attention summary to `ress status --json` that degrades to explicitly unavailable without erasing valid backup status; test malformed registry fallback and bounded output with `./tests/run.sh status-config` and `./tests/run.sh loadout-check`.
- [x] 4.3 Add `ress loadout repair [ID]` preview, dry run, confirmation, pinning, journal, and per-resource outcome handling using shared apply adapters; verify it repairs only selected missing/safe resources and never mutates during check or dry run with `./tests/run.sh loadout-repair`.
- [x] 4.4 Apply the independent AUR consent/deny/review flow to repair and preserve declined claims as pending without changing protected cleanup policy; verify `--yes` does not imply AUR permission and rerun offers deferred work with `./tests/run.sh loadout-repair` and `./tests/run.sh aur`.
- [x] 4.5 Document check, health vocabulary, exit semantics, repair, intentional external removal, and the absence of automatic repair in the loadout workflow, CLI contract, and panel status language; verify examples and state names against `./tests/run.sh loadout-check` and `./tests/run.sh loadout-repair`.

## 5. Claim Withdrawal And Package Cleanup

- [x] 5.1 Implement `ress loadout remove ID` planning and confirmation with delete, release-only, retain, already-absent, protected, and decision-required classifications; verify complete human/porcelain previews and no mutation under dry run or cancellation with `./tests/run.sh loadout-remove`.
- [x] 5.2 Implement resumable claim resolution so shared and pre-existing resources are released without deletion, already-absent resources are resolved, failures remain removal-pending, and the loadout disappears only after all claims/effects are terminal; verify interruption and rerun behavior with `./tests/run.sh loadout-remove`.
- [x] 5.3 Add explicit modified-resource resolution that either retains the resource while relinquishing cleanup authority or removes it after displaying changed evidence; verify default preservation and both explicit decisions with `./tests/run.sh loadout-remove`.
- [x] 5.4 Extend the pacman test double and implement direct dependency-respecting removal of validated owned package targets without cascade, nodeps, recursive cleanup, or orphan deletion; verify exact command arguments, dependency refusal, already-absent packages, and reported orphans with `./tests/run.sh loadout-package-remove`.
- [x] 5.5 Implement and test a fail-closed critical-package guard covering ress, package-management, privilege, and supported Omarchy runtime requirements; verify a registry claim can never override protection with `./tests/run.sh loadout-package-remove` and hostile-state cases with `./tests/run.sh loadout-registry`.
- [x] 5.6 Update `docs/contracts/restore-safety.md` and the loadout workflow with the explicit-removal exception, claim/provenance rules, modified-resource decisions, package limitations, and resumability; verify the documented preview and outcomes with `./tests/run.sh loadout-remove` and `./tests/run.sh loadout-package-remove`.

## 6. Omarchy Integration Cleanup And Theme Effects

- [x] 6.1 Extend Omarchy command doubles and implement clean pinned-plugin removal through `omarchy plugin remove --yes`, including pre-call reinspection and preservation of modified, mismatched, symlinked, or unverifiable targets; verify enable/unload/rescan delegation and pending failures with `./tests/run.sh loadout-plugin-remove`.
- [x] 6.2 Implement web-app cleanup through `omarchy webapp remove` only when launcher semantics and attributable artifacts still match, preserving externally changed launchers/icons; verify desktop/icon cleanup delegation and modified-resource decisions with `./tests/run.sh loadout-webapp-remove`.
- [x] 6.3 Implement installed-theme cleanup through `omarchy theme remove` only after evidence matches and the theme is no longer active or claimed; verify pre-existing, shared, changed, already-missing, and cleanup-failure cases with `./tests/run.sh loadout-theme-remove`.
- [x] 6.4 Implement active-theme baseline capture, monotonic last-applied precedence, fallback before deletion, and external-override preservation; test two-loadout precedence, removal of the effective request, final baseline restoration, unavailable fallback, and manual theme change with `./tests/run.sh loadout-theme-remove`.
- [x] 6.5 Document resource-specific cleanup side effects, plugin/web-app/theme command ownership, active-theme wording, and external override behavior in the registry contract, architecture, workflow, and status language; verify named commands and states against `./tests/run.sh loadout-plugin-remove`, `./tests/run.sh loadout-webapp-remove`, and `./tests/run.sh loadout-theme-remove`.

## 7. Panel Loadout Experience

- [x] 7.1 Extend `Model.js` with loadout lifecycle/resource-health formatting and parsers for the documented JSON/protocol records; add Node tests for healthy, attention, malformed, unknown, and qualified completion states and verify them with `node tests/model-test.js`.
- [x] 7.2 Extend `Service.qml` to request CLI loadout summaries/details when needed, discard malformed results, and expose terminal launch arguments without reading registry files; verify QML cross-file member checks and command construction with `./tests/run.sh qml`.
- [x] 7.3 Replace the Apply tab with a keyboard-accessible Loadouts surface that progressively shows count, attention, rows, metadata, content/resource detail, source entry, and corrective actions; verify static/QML checks and keyboard row/action coverage with `./tests/run.sh qml`.
- [x] 7.4 Route apply, update, repair, conflict resolution, and removal actions to interactive terminal commands while keeping read-only inspection in-panel; verify exact argument boundaries, no direct deletion, and no silent privilege path with `./tests/run.sh qml`.
- [x] 7.5 Reconcile `docs/panel/principles.md`, `docs/panel/status-language.md`, `docs/panel/cli-integration.md`, panel media guidance, README controls, and the `panel-integration` language with the Loadouts tab; verify documented shortcuts/actions against `Panel.qml` and `./tests/run.sh qml`.

## 8. Integration And Release Evidence

- [x] 8.1 Add a round-trip integration case applying overlapping loadouts, checking/querying state, repairing external removal, updating one profile, and removing in both orders; verify the final machine and registry invariants with the focused new cases and `./tests/run.sh`.
- [x] 8.2 Extend hostile-input and non-destructive mutation coverage for registry schema expressions, forged ownership, path-shaped IDs, fabricated claims, weakened conflict comparison, implicit repair, shared-resource deletion, modified-resource deletion, dependency cascades, and false success; verify with `./tests/mutate.sh` and record any intentional manual-only boundary.
- [x] 8.3 Run `openspec validate --all --strict`, reconcile every delta requirement with the loadout/profile/CLI/safety/panel contracts, and verify no active-change or main-spec validation errors remain.
- [x] 8.4 Run the real-machine scratch checks for package removal refusal, plugin/web-app cleanup, registry permissions, and theme fallback without touching the live vault; record commands and results in change evidence and update `docs/testing/strategy.md` with any remaining limitations.
- [x] 8.5 Execute the clean-Omarchy procedure for real apply/repair/removal transactions and the rendered Loadouts panel, record the six existing fresh-VM boundaries plus new removal/theme/panel evidence in `docs/testing/fresh-machine-validation.md`, and do not claim support for any behavior that was not observed.
