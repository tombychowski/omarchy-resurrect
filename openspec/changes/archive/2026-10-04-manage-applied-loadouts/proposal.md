# Proposal

## Why

`ress apply` can be run repeatedly, but it does not remember which loadouts were applied, which resources they share, or whether a resource was introduced by ress or already belonged to the machine. Without durable provenance and desired-state tracking, ress cannot safely report loadout health, repair drift, or remove one loadout without risking another loadout's resources or pre-existing user state.

## What Changes

- Record each confirmed loadout application as a local, versioned desired-state entry, including its validated profile snapshot, local identity, source metadata, resource claims, outcomes, and resumable operation state.
- Track canonical package, plugin, web-app, installed-theme, and active-theme resources with baseline provenance and a fail-closed cleanup policy, while detecting incompatible definitions instead of treating name collisions as satisfied resources.
- Make tracked apply account for already-present and shared resources, persist partial and deferred outcomes truthfully, and serialize loadout mutations through the ress operation lock.
- Add CLI surfaces to list and inspect applied loadouts, inspect resource provenance and claimants, check for missing or changed resources, and explicitly repair drift under the existing preview, pinning, and AUR consent safeguards.
- Make an exact reapply idempotently target the existing local loadout, while requiring an explicit, previewed `ress loadout update` operation to replace a tracked loadout with changed profile content and reconcile added or withdrawn claims.
- Add `ress loadout remove` to withdraw a loadout, remove only unchanged resources introduced by ress and no longer claimed elsewhere, preserve pre-existing or shared resources, resume interrupted cleanup, and require an explicit decision for modified resources.
- Treat theme installation and active-theme selection separately, using most-recently-applied precedence while preserving an externally selected theme and restoring a recorded baseline when appropriate.
- Conservatively handle pre-feature applications: currently present resources registered after upgrade are protected as pre-existing unless the user later makes an explicit ownership decision.
- Evolve the panel's Apply tab into a CLI-backed Loadouts surface that summarizes applied loadouts and health, exposes details, and opens interactive terminal flows for apply, repair, conflict resolution, and removal.
- Reconcile the loadout profile, CLI protocol, restore-safety, architecture, panel, workflow, README, and testing documentation with the new lifecycle. The shareable profile remains schema version 1; the new machine-local registry has its own compatibility boundary.

## Capabilities

### New Capabilities

- `applied-loadouts`: Durable local tracking of applied loadouts, normalized resource claims, provenance, conflicts, explicit profile updates, lifecycle state, and inspectable loadout/resource queries.
- `loadout-reconciliation`: Detection and explicit repair of loadout drift plus safe, resumable removal of a tracked loadout and its exclusively owned resources.

### Modified Capabilities

- `loadout-sharing`: A confirmed apply becomes a tracked desired-state operation, including no-op, shared, deferred, and partial outcomes, and rejects incompatible resource claims.
- `non-destructive-defaults`: Explicit loadout removal may delete narrowly owned resources while continuing to preserve shared, pre-existing, modified, critical, and unrelated state.
- `machine-verification`: Machine inspection reports applied-loadout health and distinguishes missing, changed, conflicting, protected, and unverifiable tracked resources.
- `explicit-execution-consent`: Loadout repair retains the independent AUR build decision and leaves declined repair work pending.
- `cli-consumer-protocol`: Stable JSON and porcelain output covers loadout lifecycle, resource queries, drift, repair, and removal for panel and automation consumers.
- `panel-integration`: The panel presents CLI-owned loadout inventory and health and delegates all loadout mutations needing review, privilege, or consent to an interactive terminal.

## Impact

- **CLI and local state:** `bin/ress` gains a versioned registry, atomic state transitions, operation recovery, loadout/resource query commands, drift inspection, repair, and removal. Apply joins the existing global operation lock and reports partial/deferred results accurately.
- **Omarchy integration:** Cleanup uses supported package-manager and Omarchy plugin, web-app, and theme commands. Package cleanup removes only explicitly tracked targets, never performs dependency cascades or orphan sweeps, and protects critical runtime resources.
- **Panel:** `Panel.qml`, `Service.qml`, and `Model.js` consume documented CLI JSON/protocol state; QML does not read or reinterpret the registry.
- **Contracts and workflows:** `docs/contracts/loadout-profile.md`, `docs/contracts/cli-protocol.md`, `docs/contracts/restore-safety.md`, `docs/architecture/system-overview.md`, panel documentation, `docs/workflows/share-apply.md`, the README, and testing guidance require reconciliation.
- **Evidence:** Automated coverage must exercise overlapping claims, provenance, conflicts, partial/interrupted operations, hostile or malformed registry input, drift and repair, exact package cleanup, modified-resource preservation, theme precedence, migration, JSON/protocol output, and panel parsing. Real package removal, live theme switching, Omarchy integration side effects, and final panel rendering remain real-machine or fresh-VM evidence.
