# Panel principles

The Montage panel is a compact native Omarchy surface over `mntg`. It presents
validated CLI state and dispatches CLI actions; it is not a repository reader,
Git client, restore engine, or second source of truth.

## One glance, then progressive detail

The bar icon answers whether a backup is missing, current, stale, or running.
The four tabs then separate distinct decisions:

- **Backup** shows freshness, capture categories, schedule, and consent policy.
- **Repositories** selects configured loadout or vault repositories, stable
  loadouts or immutable backup commits, sync state, settings, and Ress porting.
- **Share** composes the explicitly selected repository loadout.
- **Loadouts** shows desired state already applied to this machine.

Repository details appear only after an explicit selection. The panel never
loads an entire package inventory at the top level.

## The CLI is authoritative

`Service.qml` invokes only `bin/mntg`. Repository catalogs, loadout items,
backup history, synchronization, selective-share catalogs, applied-loadout
health, retention previews, and Ress port previews come from documented JSON.
Operations use the documented porcelain protocol. A malformed result becomes
unavailable; QML does not inspect Git, `montage.json`, profile leaves, backup
manifests, or local registries to fill the gap.

See [CLI integration](cli-integration.md) and the
[consumer protocol](../contracts/cli-protocol.md).

## Risk stays visible

Read-only catalog and preview requests may run in the panel. Actions that can
install software, require privilege, rewrite history, resolve synchronization,
delete exclusively owned resources, restore machine state, or publish a port
open an interactive terminal. The terminal preserves previews, confirmations,
AUR review, service consent, and error output.

The panel never silently supplies `--yes`, force-pushes, resets history, chooses
a loss waiver, or converts one plugin identity into another.

## Repositories are selected by identity

A configured name resolves through `mntg repository list --json` to a validated
path, kind, stable repository id, and credential-free remote. Loadout selection
uses a stable item id. Backup selection uses the full immutable commit. Apply,
share, and restore handoffs retain those identities.

Ress directories are never Montage live state. They appear only as read-only
port sources paired with a separate Montage destination.

## Keyboard and pointer are peers

Every action is represented in the row model used by pointer and keyboard
activation. Arrow navigation, Enter, Escape from text fields, tab switching,
and direct `b`, `r`, `o`, `s`, `a`, and `l` shortcuts are supported. Exact
bindings and focus expectations are in [Keyboard workflow](keyboard-workflow.md).

## Honest language

Missing, loading, invalid, healthy, stale, divergent, and attention are
different states. So are operation success, partial completion, failure, and
deferred work. The panel states only what the CLI result proves. Exact current
wording is defined in [Status language](status-language.md).
