# System overview

Montage is one Bash CLI with a QML bar panel. The CLI is the only authority for
machine observation, persistent state, Git-backed libraries, and mutation.

## Components

- [`bin/mntg`](../../bin/mntg) loads the literal module list, parses global flags, and dispatches commands.
- `lib/montage/repository/` owns loadout-library envelopes, configured-library schema 2 and its schema-1 migration, transactions, exact historical reads, and conservative synchronization.
- `lib/montage/loadout/` owns portable profiles, applied-state provenance and claims, planning, Share, apply, check, repair, update, remove, and resource queries.
- `lib/montage/machine/packages.sh` owns installed-package/theme observation and package/AUR operations.
- `lib/montage/port/ress.sh` is the single read-only foreign-input adapter for one Ress v1 profile.
- `lib/montage/commands.sh` owns status, AUR configuration, doctor, and guarded PATH linking.
- `Service.qml` invokes documented CLI JSON or porcelain routes and rejects malformed results through `Model.js`.
- `Panel.qml` presents Libraries, Compose/Share, and Applied Loadouts. Risky synchronization, apply, lifecycle, and migration work continues in an interactive terminal.

The manifest registers only the bar widget. There is no background service or
timer-owned product operation.

## Persistent state

| Location | Purpose |
|---|---|
| `~/.config/montage/config` | ordered loadout settings; currently `AUR` |
| `~/.config/montage/repositories.json` | loadout-only configured-library registry |
| `~/.config/montage/repositories.json.pre-schema2` | inert exact rollback copy after one-time migration |
| `~/.local/state/montage/loadouts.json` | applied snapshots, provenance, resources, claims, and operation journal |
| `~/.local/state/montage/status-evidence.json` | advisory update evidence created only by explicit update preview |
| `~/.local/state/montage/lock`, `running` | live mutation ownership |
| user-selected library paths | schema-1 loadout repository envelopes and stable items |

Status reads valid current state locally. A legacy configured-library registry
is the one exception: its first read performs the locked schema migration.

## Main flows

Compose discovers current safe resources in the CLI, accepts stable logical
ids, reinspects before publication, stages a complete item, validates it, and
publishes through the repository transaction boundary.

Apply resolves one profile and exact provenance, plans additive work, obtains
operation and AUR consent, records desired state before mutation, and journals
outcomes. Check is read-only; repair is explicit; update advances the same
immutable library/item identity; remove acts only on recorded claims.

Library synchronization explicitly fetches into a Montage observation ref.
Fast-forward pull and ordinary push are opt-in; divergence is decision-required.
Ordinary status uses only the cached result.

Ress migration discovers one contained regular v1 profile, reports exact losses
and decisions, translates in staging, validates the native result, and publishes
one selected item. Source content and operational authority never transfer.

## Trust boundaries

- Profiles, envelopes, registries, remotes, and Ress input are untrusted and structurally validated before authority is derived.
- AUR crosses an execution boundary and has separate consent.
- Applied state crosses a deletion-authority boundary and is validated as a whole before use.
- Network state changes only through explicit sync or source resolution.
- QML crosses a consumer boundary and treats malformed results as unavailable.

See [CLI modules](cli-modules.md), [contracts](../contracts/), and the
[testing strategy](../testing/strategy.md).
