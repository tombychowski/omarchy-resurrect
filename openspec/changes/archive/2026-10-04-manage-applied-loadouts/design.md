# Design

## Context

See `proposal.md` for motivation. Today `cmd_apply` computes missing actions from live machine presence, mutates packages and Omarchy integrations, and discards the fetched profile when the process exits. It does not take the global ress operation lock, persist per-resource outcomes, distinguish an equivalent resource from a name collision, or qualify several warning paths in its final success result.

The existing architecture imposes four important constraints:

- `bin/ress` remains authoritative for inspection, validation, mutation, persistent state, and consumer output. QML must not read or reinterpret a loadout registry.
- Loadouts remain untrusted, fixed-schema input. Registry content is local but hand-editable and must also be validated before it can authorize deletion.
- Existing preservation, pinning, AUR consent, and dry-run guarantees remain in force. Explicit loadout removal adds narrow deletion authority; it does not weaken additive restore or apply behavior.
- Package installation/removal, Omarchy integration side effects, active-theme switching, and final panel rendering need real-machine or fresh-VM evidence in addition to command-boundary tests.

## Goals / Non-Goals

**Goals:**

- Make confirmed loadouts durable desired-state objects whose health and provenance can be inspected offline.
- Make overlapping loadouts share compatible resources without losing the baseline fact that controls later cleanup.
- Make apply, update, repair, and removal crash-aware, resumable, and truthful about deferred, partial, conflicting, and uncertain work.
- Keep all destructive decisions resource-specific and fail closed when identity, ownership, or current evidence is uncertain.
- Give the panel a compact CLI-backed inventory while keeping review, privilege, and consent in an interactive terminal.

**Non-Goals:**

- Synchronizing a loadout continuously with a remote repository or polling for upstream changes.
- Version pinning ordinary packages beyond what the current profile declares.
- Removing transitive dependencies, orphan packages, application data, arbitrary configuration, or other resources not explicitly represented by a loadout claim.
- Retrofitting reliable ownership onto applications performed by older ress versions.
- Moving the registry between machines through the vault, a shared loadout, or a hosted service.
- Automatically repairing drift from status checks or panel refreshes.

## Decisions

### 1. Use one versioned local JSON registry

Store the registry under `${XDG_STATE_HOME:-$HOME/.local/state}/ress/` as a private, inspectable JSON file with an independent integer schema version. The logical records are:

```text
registry
  version, revision
  machine baseline effects
  loadouts[]
    local id, metadata, sanitized source, normalized profile, digest
    applied/updated timestamps, precedence, lifecycle state
  resources[]
    canonical id, kind, expected definition
    first observation, cleanup policy, current evidence
  claims[]
    loadout id, resource id, requested definition, outcome
  operation
    kind, target, phase, planned actions, per-action state
```

Claims are a canonical relation rather than duplicated claimant lists inside both loadout and resource records. Queries derive either direction from that relation. The normalized profile snapshot is still stored on the loadout because it is the reviewed input and enables offline display, repair, and removal; it is not an independent ownership list.

Writes use a same-directory temporary file, full schema/invariant validation, restrictive permissions, and atomic rename. A monotonically increasing revision makes stale read-modify-write attempts detectable. The main ress operation lock serializes backup, restore, apply, update, repair, and removal; read-only queries may take a shared or short-lived registry lock if required for a consistent snapshot.

Alternatives considered:

- **SQLite:** stronger relational mechanics, but unnecessary for the expected record count and less directly inspectable. It would also add a runtime dependency to a shell-first tool.
- **One profile and manifest file per loadout:** easy to browse, but multi-file claim updates cannot commit atomically and make crash recovery harder.
- **A resource manifest only:** cannot preserve profile snapshots, lifecycle status, update identity, or an interrupted operation without adding parallel stores.

### 2. Treat registry data as mutation-authorizing input

The registry is not remotely fetched, but a user or faulty prior version can edit it. Every mutation reloads and validates the full registry after acquiring the lock. It accepts only the supported version, known enums, bounded safe identifiers, valid references, and internally consistent loadout/resource/claim links.

Deletion targets are reconstructed from validated logical resource identities; the registry never stores an arbitrary deletion path or command. Unsupported versions, dangling claims, duplicate canonical identities, unknown operation states, and invalid identifiers block mutation while remaining reportable to read-only diagnostics.

The registry stores sanitized sources without credentials. It contains no fetched repository content, package build instructions, secrets, or arbitrary executable fields. It is excluded from vault capture and loadout export because provenance is machine-specific.

### 3. Use local identity plus normalized profile digest

The shareable profile remains schema version 1. On first confirmation, ress assigns a readable local identity derived from the validated name plus a collision-resistant digest suffix. The cryptographic digest of canonical normalized profile content identifies an exact reapplication; display metadata ordering and unknown fields do not produce distinct identities.

Applying an exact tracked digest targets the existing loadout for reconciliation. If a known sanitized source now produces a different digest, ordinary apply refuses to replace the old snapshot silently. The user chooses either:

- `ress loadout update ID [SOURCE]`, which previews added, retained, conflicting, and withdrawn claims; or
- a separately identified new application, subject to normal conflict checks.

An update uses the removal engine for withdrawn claims, so omission from a changed remote profile never becomes implicit deletion during ordinary apply.

Adding an author-controlled ID to the public profile was rejected for this change: it requires a profile compatibility decision, permits unrelated publishers to collide deliberately, and is not needed for safe local lifecycle management.

### 4. Canonicalize identities but compare kind-specific definitions

Canonical resource IDs are logical values, not paths:

```text
package:<name>
plugin:<id>
webapp:<validated-label>
theme-install:<name>
theme-active:<loadout-id>
```

Packages share by package name. The native/AUR channel remains claim metadata and a channel disagreement is reported; ress does not attempt two installations of one package name. Packages are presence-based because schema version 1 carries no version constraint.

Plugins share only when ID, normalized safe remote, and resolved pinned commit match. If the user explicitly accepts an unpinned apply, ress records the actual resulting commit as evidence so later comparison and repair do not silently follow a moving branch.

Web apps share only when label, URL, icon reference, and other represented launcher semantics match. Presence of `<label>.desktop` alone is not satisfaction. After successful installation, ress records the generated launcher's parsed semantics and digest plus any safely attributable generated icon artifacts.

Installed themes share only when name, normalized remote, and resolved commit match. Theme installation and active selection are separate because many themes may exist while only one is active.

An identity collision with a different definition is a conflict, not an already-installed resource. Conflict resolution is explicit and must not rewrite another loadout's claim as a side effect.

### 5. Baseline provenance determines cleanup authority

Before the first claim can mutate a resource, ress records whether a compatible resource was present:

- `firstObserved=present`, `cleanupPolicy=retain`: it belonged to the machine before tracking.
- `firstObserved=absent`, then successful install, `cleanupPolicy=remove`: ress introduced it.
- `firstObserved=unknown` or interrupted action, `cleanupPolicy=unknown`: ress cannot safely delete it until explicitly resolved.

Adding further claims never changes this baseline. Repairing a protected resource also leaves `cleanupPolicy=retain`; repair is fulfillment of desired state, not retroactive ownership adoption.

Because no earlier ress version recorded the pre-mutation fact, reapplying a historical loadout after upgrade marks every compatible present resource as protected. A future explicit adoption feature could change cleanup authority, but no heuristic in this change does so.

### 6. Journal before mutation and record after every action

Dry runs acquire enough locking for a coherent plan but write neither desired state nor progress. After confirmation, a live operation writes its target, plan, baseline observations, and pending claims before the first external mutation. Each resource action moves through planned, running, and a terminal outcome, with an atomic registry write after each transition.

No local transaction can atomically include `pacman`, Git, or an Omarchy command. If interruption leaves an action in `running`, recovery inspects current kind-specific evidence:

- a provably unchanged completed result may be finalized;
- a provably absent result may be retried;
- ambiguous evidence becomes `uncertain` with unknown cleanup authority and requires explicit resolution.

An uncertain action is never reclassified as pre-existing merely because the resource is present after restart.

Loadout lifecycle is derived from claims and the active operation: healthy, pending, drifted, conflicting, removal-pending, or unavailable. Consumer completion records use `ok` only when no required claim remains unresolved; qualified completion uses the established partial/failure distinctions and structured resource records.

### 7. Check is read-only; repair is explicit

`ress loadout check [ID] [--json]` inspects all or one tracked loadout without mutation. `ress loadout repair [ID] [--dry-run]` constructs a plan only for missing or safely repairable claims and uses the same validators, exact pins, previews, confirmation, and independent AUR gate as apply.

Kind-specific comparison is deliberately asymmetric:

- packages: named presence only;
- plugins/themes: safe remote, HEAD commit, and local-change evidence;
- web apps: validated launcher semantics and recorded attributable artifacts;
- active theme: current selection versus managed precedence, while recognizing an external override.

Status may include only a compact count/attention summary. Detailed list, content, resource, and drift JSON comes from dedicated commands so routine backup status remains bounded. The panel requests those CLI results when the Loadouts tab is active.

Automatic repair was rejected because it could invoke `sudo`, fetch code, build AUR packages, reverse intentional user removal, or change the active theme without contemporaneous consent.

### 8. Remove claims first conceptually, resources only with proof

`ress loadout remove ID` plans from a fresh inspection and groups actions as delete, release-only, retain, already absent, protected, or decision required. After confirmation it resolves each claim:

- another claimant remains: release only;
- baseline cleanup policy is retain: release and retain;
- resource is already absent: release and report external cleanup;
- final claim, policy is remove, resource matches evidence: invoke supported cleanup then release;
- resource is changed, critical, unverifiable, or cleanup fails: keep the claim and loadout in removal-pending.

The user can explicitly resolve a changed resource by keeping it, which relinquishes cleanup authority, or by authorizing removal after the changed evidence is shown. The command removes the loadout from active tracking only after all claims and active-theme effects are terminal. A separate `forget` recovery operation, if exposed, must preview that it leaves every resource and relinquishes all cleanup authority; it is not an alias for remove.

The same engine resolves withdrawn claims during `loadout update`, preventing two subtly different cleanup implementations.

### 9. Use supported cleanup mechanisms with conservative package rules

Resource adapters provide inspect, install/repair, and remove operations:

- **Packages:** remove only validated direct targets through a dependency-respecting pacman removal. Never use cascade, nodeps, recursive dependency cleanup, or an automatic orphan sweep. Dependency refusal leaves removal pending. Orphans may be reported as follow-up information.
- **Plugins:** verify origin, commit, and local cleanliness, then use `omarchy plugin remove --yes` so enabled-state unloading, backups where applicable, and shell rescan follow Omarchy behavior. When both shell IPC and the shell process are confirmed absent, rerun that same remover with narrowly scoped no-live-shell responses for its enabled-state query and rescan; Omarchy continues to own validation and deletion. A live but unresponsive shell leaves removal pending.
- **Web apps:** verify the launcher still matches, then use `omarchy webapp remove` so launcher/icon cleanup and desktop database refresh follow Omarchy behavior. Attributable artifacts that changed are not deleted silently. If a delegated command returns nonzero after deletion, reinspection of the resource postcondition decides success; this covers best-effort cache-refresh failure without hiding a resource that remains present.
- **Themes:** switch away first, then use `omarchy theme remove` only for an unchanged user-installed theme introduced by ress.

A protected-package guard covers package-manager, privilege, ress runtime, and supported Omarchy runtime requirements. Ownership evidence never overrides that guard. If protection cannot be decided confidently, retain and report.

Direct filesystem removal remains limited to cleaning a failed clone target proven absent at baseline, as today; successful lifecycle cleanup goes through supported resource commands.

### 10. Model active theme as an ordered effect

The registry captures the baseline active theme before the first managed theme selection and assigns each successfully applied or updated loadout a monotonic precedence value. The effective managed request is the highest-precedence remaining usable theme.

Before deleting a currently active managed theme, removal switches to the next effective request. When none remains, it restores the baseline if available. If the current theme differs from the effective managed request without a matching ress operation, ress records an external override. Unrelated removal preserves that override and reports divergence rather than forcing the managed choice.

This behaves like a small effect stack, not resource reference counting. It avoids deleting the active theme and makes last-applied-wins deterministic without pretending simultaneous theme selections can all be satisfied.

### 11. Keep the panel compact and terminal-mediated

The third panel tab becomes Loadouts rather than adding a fourth dashboard. Its initial view shows a count, attention summary, applied loadout rows, and an add action. Selection progressively reveals metadata, resource counts, health, and available corrective actions.

`Service.qml` invokes documented JSON commands and discards malformed results. `Model.js` formats and parses stable records. Neither reads the registry. Apply, update, repair, conflict resolution, and removal open a terminal; they may require lengthy review, `sudo`, destructive confirmation, or an independent AUR decision. Read-only list/detail state can render in-panel.

### 12. Reconcile contracts and evidence at their owning layers

The loadout profile contract documents that schema version 1 is unchanged and that apply now stores a normalized local snapshot. A new loadout-registry contract owns the machine-local schema and invariants. The CLI protocol owns JSON and porcelain shapes. Restore-safety documents the narrow explicit-removal exception. Architecture describes persistence and trust boundaries. The share/apply workflow and panel documents own user journeys and wording.

The shell test harness remains the primary command-boundary evidence. Fake package and Omarchy commands must gain removal and drift fixtures without asserting behavior their real counterparts do not provide. Model/QML tests cover consumer parsing and cross-file bindings. Actual package transactions, plugin/web-app cleanup side effects, theme transitions, and visual panel behavior are recorded as real-machine or fresh-VM evidence.

## Risks / Trade-offs

- **[Registry says ress owns something it did not create]** -> Record baseline before mutation, journal uncertain windows, validate invariants, and default unknown/historical provenance to retain.
- **[External mutation occurs between inspection and cleanup]** -> Hold the ress lock, re-inspect immediately before each destructive adapter call, and stop removal when evidence changed.
- **[A command succeeds but state recording is interrupted]** -> Persist running intent first, reconcile kind-specific evidence on resume, and require a decision when evidence is ambiguous.
- **[Two loadouts use one name for different content]** -> Compare complete represented definitions and surface a conflict rather than using existence as satisfaction.
- **[Package cleanup removes useful dependencies]** -> Remove direct targets only, honor dependency refusal, protect critical packages, and report rather than delete orphans.
- **[Theme removal leaves an unusable desktop]** -> Resolve and activate a fallback before deleting files; preserve detected external selection.
- **[Registry growth makes shell/JQ operations slow]** -> Keep one bounded normalized snapshot per applied loadout, avoid captured payloads, and measure representative large registries before considering a database.
- **[Panel becomes a dense management dashboard]** -> Fetch details only in the Loadouts tab, use progressive disclosure, and keep mutation review in the terminal.
- **[Old binaries ignore new state]** -> The registry is additive and separate; rollback leaves resources and registry untouched, while old ress continues its prior additive behavior without gaining deletion authority.

## Migration Plan

1. Introduce registry parsing, validation, atomic writes, locking, read-only queries, and malformed-state diagnostics before any removal path exists.
2. Convert apply to record baselines, claims, outcomes, exact reapplication, and explicit changed-profile handling while retaining schema version 1 compatibility.
3. Add checking and repair, then exercise interruption and uncertain-action recovery before enabling cleanup.
4. Add claim withdrawal/update and resource-specific removal behind complete dry-run previews; keep modified and critical resources pending by default.
5. Add active-theme precedence and fallback, followed by panel consumption of stable CLI JSON/protocol output.
6. Reconcile documentation and record automated, real-machine, and fresh-VM evidence before treating removal as supported.

There is no automatic import of historical applications. The first confirmed post-upgrade application records compatible present resources as protected. Rolling back to an older ress version leaves the registry unused and performs no cleanup; reinstalling the new version resumes from the preserved registry after validation.
