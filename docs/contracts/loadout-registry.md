# Applied-loadout registry

The applied-loadout registry is private, machine-local desired state owned exclusively by `bin/mntg`. It is stored at `${XDG_STATE_HOME:-$HOME/.local/state}/montage/loadouts.json`; an absent file means that no loadouts are tracked. It is not part of a vault repository, loadout repository, portable profile, or Ress port artifact.

## Version 1 shape

The root object contains `schemaVersion`, a monotonically increasing `revision`, `baseline`, `loadouts`, `resources`, `claims`, and an optional `operation` journal.

- A loadout stores its collision-safe local `id`, display metadata, credential-stripped `source`, optional immutable repository id and stable loadout id, resolved commit, canonical profile `digest`, normalized profile snapshot, timestamps, theme precedence, and lifecycle `state`. Repository provenance is all present or all `null` for a standalone profile.
- A resource stores a canonical logical `id`, `kind`, safe name, represented definition, `firstObserved`, immutable cleanup policy, last recorded state, and kind-specific evidence.
- A claim relates one loadout to one resource and stores the requested definition, current outcome, and last error. Claimant lists are derived from this relation.
- The baseline records the active theme observed before the first managed theme effect.
- An operation records `apply`, `update`, `repair`, or `remove`, its loadout target, phase, and planned/running/terminal action states.

Canonical resource identities are `package:<name>`, `plugin:<id>`, `webapp:<label>`, `theme-install:<name>`, and `theme-active:<loadout-id>`. Installed theme content and active-theme intent are deliberately distinct resources.

## Provenance and cleanup authority

`firstObserved` records whether a resource was present before its first native Montage claim. A present resource receives cleanup policy `retain`; a missing resource introduced by Montage receives `remove`. Later claims and repairs do not upgrade `retain` or unknown provenance into deletion authority. Compatible definitions share one resource. Conflicting definitions remain explicit claim conflicts.

Ress registries, ownership claims, cleanup observations, and imported provenance are never copied into this registry or treated as Montage authority. A ported portable profile must be confirmed and observed on this machine through the ordinary Montage apply plan before it can create native claims. Unknown legacy ownership fields make the exact registry invalid rather than silently granting removal rights.

A registry record never authorizes an arbitrary path. Mutation reconstructs targets from validated logical identities and re-inspects machine evidence immediately before cleanup. Shared, pre-existing, missing, changed, symlinked, critical, and unverifiable resources follow the preservation rules in [Restore safety](restore-safety.md).

## Validation and writes

Every mutation acquires the main Montage operation lock, reloads the registry, and validates the complete document. Version 1 requires exact record fields, known enums, bounded safe identities, unique loadout/resource/claim keys, coherent repository provenance, and non-dangling relations. Unsupported versions, malformed JSON, duplicates, hostile names, imported ownership annotations, or fabricated references block mutation.

Writes use a mode-`0600` temporary file in the registry directory, validate the candidate, compare its starting revision, and atomically rename it. The state directory is private. A stale revision or invalid candidate is never installed.

The operation journal is persisted before machine mutation and updated after each action. On resume, present/absent evidence may classify an interrupted action as completed or retryable. Ambiguous evidence becomes `uncertain`; it is never silently reclassified as pre-existing or safe to delete.

## Resource-specific evidence and cleanup

- Packages are present by validated package name. Cleanup invokes direct `pacman -R` targets only, respects dependency refusal, never cascades or removes orphans, and rejects critical Montage/Arch/Omarchy runtime packages.
- Plugins and Git themes compare safe remote, pinned commit, dirty worktree, target type, and required metadata. Clean removal is delegated to the corresponding `omarchy` command.
- Web apps compare validated launcher semantics, URL, icon, and launcher digest. Cleanup is delegated to `omarchy webapp remove` only after matching evidence.
- Active themes use last-successful-loadout precedence. Removal switches to the newest usable remaining request or the captured baseline before removable theme content is deleted. A detected external selection is preserved.

Registry evidence describes the last recorded transaction; `mntg loadout check` performs the live comparison. Read-only commands do not repair or rewrite state.

## Queries and exclusion

`mntg loadout list/show` and `mntg resource list/show` are the supported consumer boundary. QML does not read this file. Registry content is excluded from `mntg share` by the profile's fixed schema and from vault capture because Montage state is self-excluded. Sources are stored without URL credentials; fetched repositories, PKGBUILDs, secrets, and arbitrary executable content are never stored here.
