# CLI module architecture

`bin/mntg` and the modules it sources form one Bash program and one authority.
The QML panel, people, and tests invoke the same entrypoint.

## Literal load order

```text
bin/mntg
  ├─ core.sh → safety.sh
  ├─ repository/common.sh → registry.sh → transaction.sh → reader.sh
  │                                      → sync.sh → commands.sh
  ├─ machine/packages.sh
  ├─ loadout/registry.sh → profile.sh → repository.sh → resources.sh
  │                     → planning.sh → share.sh → lifecycle.sh → apply.sh
  ├─ commands.sh
  └─ port/ress.sh → commands.sh
```

The literal `MONTAGE_MODULES` array in [`bin/mntg`](../../bin/mntg) is the
runtime source of truth. [`tests/module-dependencies.tsv`](../../tests/module-dependencies.tsv)
is its reviewed dependency model; structural tests compare both and reject
unreachable functions or reverse machine-to-state dependencies.

## Ownership table

| Module | Owns |
|---|---|
| `core.sh` | paths, flags, output, AUR config serialization, locks, bounded temporary cleanup |
| `safety.sh` | names, URLs, credential removal, source normalization, contained files, web-app parsing, pinned Git retrieval |
| `repository/common.sh` | fixed schema-1 loadout envelope and identity validation |
| `repository/registry.sh` | loadout-only configured registry schema 2, locked schema-1 migration, and shared migration reporting |
| `repository/transaction.sh` | repository locks, staging, journals, recovery, clean-tree and content-sensitive commit rules |
| `repository/reader.sh` | bounded refs and isolated exact historical trees |
| `repository/sync.sh` | explicit fetch classification, fast-forward pull, ordinary push, divergence refusal |
| `repository/commands.sh` | repository human/JSON/porcelain consumer routes |
| `machine/packages.sh` | installed package/theme observation, repository/AUR classification, consent, package effects |
| `loadout/registry.sh` | applied-state schema, provenance, claims, operation journal, advisory update evidence |
| `loadout/profile.sh` | portable profile schema, normalization, digest, resource projection |
| `loadout/repository.sh` | stable library items, catalog, exact selection, item publication |
| `loadout/resources.sh` | live resource inspection and guarded effects |
| `loadout/planning.sh` | compatibility, preservation, claims, and additive plans |
| `loadout/share.sh` | canonical machine catalog and selective profile/README rendering |
| `loadout/lifecycle.sh` | list/show/check/repair/update/remove and operation recovery |
| `loadout/apply.sh` | apply preview, consent, journaling, and outcome protocol |
| `commands.sh` | loadout attention status, `set`, `doctor`, and guarded `link` |
| `port/ress.sh` | contained Ress v1 inspection, loss decisions, translation, and one-item transaction |
| `port/commands.sh` | the focused `port ress inspect` and `port ress import loadout` grammar |

All modules contain definitions only at source time. `bin/mntg` loads config
after successful source completion, then dispatches.

## Dependency direction

Core and safety know no domain state. Repository primitives know envelope and
transaction mechanics but not applied claims. Machine observation never writes
registries. Loadout modules may use repository and machine primitives. The Ress
adapter may validate a native profile and publish through a repository
transaction, but native modules do not depend on it. QML is outside this graph
and consumes only CLI output.

## State ownership

| State | Owner |
|---|---|
| `CFG`, operation/config locks, temporary paths | `core.sh` |
| configured libraries and one-time migration facts | `repository/registry.sh` |
| transaction stage, journal, and exact commit | `repository/transaction.sh` |
| applied loadouts, claims, and operation journal | `loadout/registry.sh` |
| machine observation snapshot | `machine/packages.sh` |
| profile application workspace and resolved provenance | `loadout/repository.sh` / `apply.sh` |
| Ress inspection and translation staging | `port/ress.sh` |

## Extension rules

A new portable profile field belongs in `profile.sh`, then planning, resource
effects, Share, lifecycle, contracts, and preservation tests. A new library
operation belongs behind repository validation and transaction boundaries. A
new status fact needs validated local evidence and a documented precedence; it
must not add implicit network access. Another foreign format or reverse
conversion requires a new product decision instead of expanding the frozen Ress
adapter.
