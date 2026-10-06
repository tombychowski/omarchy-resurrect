# CLI module architecture

The ress CLI is one Bash program distributed across a public entrypoint and
sourced implementation modules. [`bin/ress`](../../bin/ress) remains the only
executable interface: the panel, scheduler, tests, and PATH symlink invoke it,
and it remains authoritative for machine inspection, validation, mutation,
persistent state, and consumer output.

Splitting the implementation does not create a plugin API or separate command
processes. Every module runs in one shell process and therefore shares strict
mode, functions, variables, locks, traps, and exit status.

## Startup and dispatch

For every invocation, `bin/ress`:

1. enables `set -euo pipefail`;
2. follows any symlink to its real `bin` directory and derives the plugin root;
3. checks and sources a literal list of required modules in dependency order;
4. installs the one process cleanup trap;
5. parses global options, then loads CLI-owned configuration;
6. selects one command and calls its `cmd_*` function.

A missing or unreadable module stops startup before configuration loading,
locking, network access, or mutation. Loading writes nothing to stdout, so JSON
and porcelain output are protocol-clean from the first byte.

```text
bin/ress
  +--> core.sh --> safety.sh
  +--> machine/packages.sh
  +--> vault/common.sh --> backup.sh / restore-state.sh / restore-preview.sh
                         --> restore.sh / verify.sh / commands.sh
  +--> loadout/registry.sh / profile.sh / resources.sh / planning.sh
                              +--> share.sh / lifecycle.sh / apply.sh
```

This diagram groups ownership; the literal source order remains the list in
`bin/ress`. All modules load before dispatch, so runtime function calls may
cross that source order without causing a module to source another module.

`vault/commands.sh` owns the combined `status` command. After the complete
module list has loaded, that command calls loadout-owned validation and checking
functions for its loadout summary; it never reads or interprets registry JSON
itself. This is a runtime query dependency, not shared format ownership.

The entrypoint owns the source list. Modules never source other modules, and a
glob never decides what code becomes part of the CLI.

## File ownership

| File | Contents and state | Used by / dependencies |
|---|---|---|
| [`bin/ress`](../../bin/ress) | Root resolution, required-module loading, cleanup-trap installation, usage, global option parsing, config-load timing, dispatch | Invoked by people, QML, the scheduler, and tests; loads every row below |
| [`lib/ress/core.sh`](../../lib/ress/core.sh) | Versions and format constants, derived paths, ordered configuration schema and `CFG`, output, flags, bounded temporary creation/cleanup, and locks | Foundation for every module; expects `PLUGIN_DIR` from the entrypoint |
| [`lib/ress/safety.sh`](../../lib/ress/safety.sh) | Untrusted-name/schema/URL validators, terminal sanitization, source normalization, credential stripping, pinned Git retrieval, Desktop Entry web-app parsing | Shared by vault and loadout code; depends on core output and flags |
| [`lib/ress/machine/packages.sh`](../../lib/ress/machine/packages.sh) | Installed-package and active-theme snapshots, repository/AUR probing, AUR consent, package installation helpers | Neutral machine operations; owns no vault, profile, or registry representation |
| [`lib/ress/vault/common.sh`](../../lib/ress/vault/common.sh) | Selected `VAULT`, Git helpers, current/legacy manifest lookup, safe manifest JSON, vault initialization | All vault modules; depends on core and safety policies |
| [`lib/ress/vault/backup.sh`](../../lib/ress/vault/backup.sh) | Category capture, backup credential scan, manifest writing, commit and push | `backup`, and scan reporting shared with `scan`; depends on core, safety, vault common |
| [`lib/ress/vault/restore-state.sh`](../../lib/ress/vault/restore-state.sh) | Restore progress, failure, partial-result, first-contact and unit-choice state | Restore preview and orchestration; depends on core |
| [`lib/ress/vault/restore-preview.sh`](../../lib/ress/vault/restore-preview.sh) | Restore-wide executable-content/package/plugin preview and unit-decision interpretation | Restore orchestration; depends on core, safety, machine operations, vault common and restore state |
| [`lib/ress/vault/restore.sh`](../../lib/ress/vault/restore.sh) | Private-vault category replay, service consent execution, resumable orchestration | `restore`; depends on core, safety, machine operations, vault common, restore state and preview |
| [`lib/ress/vault/verify.sh`](../../lib/ress/vault/verify.sh) | Machine comparison, explicit scan, deferred unit enablement | `verify`, `scan`, `enable-units`; uses capture/restore parsing rules rather than inventing alternatives |
| [`lib/ress/vault/commands.sh`](../../lib/ress/vault/commands.sh) | Status, initialization, settings, secrets setup, PATH link, doctor, and diffs | `status`, `init`, `set`, `secrets`, `link`, `doctor`, `diff`; depends on core, safety, vault common, while `status` consumes loadout-owned query functions after startup |
| [`lib/ress/loadout/registry.sh`](../../lib/ress/loadout/registry.sh) | Registry validation/persistence, command-local indexes, operation journal, claim registration and outcomes | All tracked-loadout commands; owns registry state, schema, indexes and transitions |
| [`lib/ress/loadout/profile.sh`](../../lib/ress/loadout/profile.sh) | Fetch, normalization, digest and local identity, normalized profile-to-resource conversion | `share`, `update`, `apply`; depends on core and safety |
| [`lib/ress/loadout/resources.sh`](../../lib/ress/loadout/resources.sh) | Snapshot-backed inspection plus immediate live rereads for guarded install, remove, and theme effects | `share`, `check`, `repair`, `update`, `remove`, `apply`; depends on machine observations and registry-owned outcomes |
| [`lib/ress/loadout/planning.sh`](../../lib/ress/loadout/planning.sh) | Definition compatibility and apply/update/repair plan construction | Apply and lifecycle orchestration; depends on profile, registry indexes and resource inspection |
| [`lib/ress/loadout/share.sh`](../../lib/ress/loadout/share.sh) | Candidate discovery, catalog, selection and withdrawal validation, profile/README rendering | `share`; depends on profile, registry, and live resource inspection |
| [`lib/ress/loadout/lifecycle.sh`](../../lib/ress/loadout/lifecycle.sh) | Queries, recovery, checking, repair, update, claim release and removal | `loadout`, `resource`; depends on registry/profile/resources |
| [`lib/ress/loadout/apply.sh`](../../lib/ress/loadout/apply.sh) | Apply orchestration | `apply`; depends on machine operations, registry/profile/resources/planning and lifecycle handoff |

Vault modules and loadout modules may share safety primitives, but neither reads
or reinterprets the other's persistent format. A private vault can represent
selected files and encrypted secrets; a public loadout intentionally cannot.
See [Vault format](../contracts/vault-format.md), [Loadout profile](../contracts/loadout-profile.md),
and [Applied-loadout registry](../contracts/loadout-registry.md).

## Source-time rules

A module may define functions, constants, arrays, and initial in-memory state.
Merely sourcing it must not:

- parse command-line arguments or dispatch a command;
- install or replace a trap;
- acquire a lock or create its marker;
- inspect or mutate a vault, registry, profile, or machine resource;
- contact a remote; or
- write stdout or stderr.

The entrypoint installs `ress_cleanup` once all required modules have loaded.
Command functions acquire locks at the same operation boundaries described by
the [system overview](system-overview.md) and persistent-state contracts. Core
tracks primary-lock ownership separately from panel-marker ownership. A
non-dry-run owner writes an opaque marker token, and cleanup removes the marker
only when the current contents still match that process's token. The dedicated
configuration lock is also fail-closed: timeout ends the setting command before
its protected reread or write.

## Shared state ownership

Bash cannot enforce private module fields, so ownership is a review and testing
rule rather than a language feature.

| State | Owner | Notes |
|---|---|---|
| Global flags (`PORCELAIN`, `DRY_RUN`, consent choices), operation/marker ownership, and `CFG` | `core.sh` | Parsed/set by the entrypoint or command options, then read by workflows |
| Config, state, defaults and Omarchy paths | `core.sh` | Derived only after the entrypoint establishes the plugin root |
| `VAULT` | `vault/common.sh` | Selected through `resolve_vault`; loadout code does not use it as loadout state |
| Restore progress, failures, partial work, first contact and unit decision | `vault/restore-state.sh` | Scoped to one command process and persisted only through documented restore state |
| Installed-package and active-theme observations | `machine/packages.sh` | Built once for a stable planning/check phase, reset after mutation, never persisted |
| Credential scan findings | `vault/backup.sh` | Contains file/rule identifiers, never matched secret text |
| Registry document, revision, schema, journal and derived indexes | `loadout/registry.sh` | Mutations validate the whole document; indexes invalidate on save |
| Profile/apply work directories and normalized profile state | `loadout/profile.sh` and `share.sh` | Created through bounded core helpers and registered by exact path |

Only `core.sh` owns cleanup and lock implementations. A domain requests a
temporary file/directory through controlled helpers; core validates the real
path against the requested parent and records its type before cleanup may
remove it. Domains do not add cleanup globals or another EXIT trap. The exact
state locations remain documented in the
[system overview](system-overview.md).

Stable multi-resource plans/checks use one command-local observation snapshot.
Destructive guards and post-mutation checks use live truth; a mutation resets
the snapshot before the final health view. Registry indexes similarly derive
from one validated value and are invalidated on save.

## Adding or changing functionality

### Add a command

Place `cmd_<name>` in the domain that owns its state and operations, add only
the dispatch arm and usage text to `bin/ress`, and keep all inspection and
mutation inside the CLI. Add focused human/JSON/porcelain and exit-status tests
as applicable. Update the file table when ownership changes; update contracts or
OpenSpec only when observable behavior changes.

### Add a setting

Add the key once to core's ordered `CONFIG_KEYS`, `CONFIG_DEFAULTS`, and
`CONFIG_TYPES`, plus `CONFIG_CHOICES` when constrained. Loading, validation,
stable saving, and status conversion must use that metadata rather than a
second key list. Update the config/CLI contract and panel presentation as
needed, but keep QML a consumer that writes only through `ress set`.

### Add a vault category

Keep capture and replay logic in the vault modules, add the category to the
configured category list and restore order deliberately, and reuse shared
validators for any untrusted fields. Reconcile manifest/restore contracts,
preview and consent behavior, verification, omission reporting, and automated
or manual evidence. A category that can execute fetched code or arrange future
execution needs its own informed consent analysis.

### Add a loadout resource

Keep the public profile definition constrained and declarative. Put schema and
normalization in `profile.sh`, registry invariants in `registry.sh`, live
inspection and guarded mutation in `resources.sh`, then connect share/apply and
lifecycle orchestration. Define identity, conflict compatibility, provenance,
cleanup authority, drift evidence, and consumer output together. Do not reuse a
vault file representation merely because both features mention the same tool.

## Evidence for module changes

[`tests/run.sh`](../../tests/run.sh) syntax-checks the entrypoint and every
`.sh` file below `lib/ress/` before running cases. Existing cases invoke the
entrypoint, so they test the composed CLI. [`tests/cases/41-cli-modules.sh`](../../tests/cases/41-cli-modules.sh)
covers direct, symlinked, relocated, JSON/porcelain, and incomplete-tree startup.

Each mutation in [`tests/mutate.sh`](../../tests/mutate.sh) names its owning
production file and one detector case. The runner proves one clean full-suite
baseline, then injects every fault and requires its detector to go red. Moving a
function requires moving that target; an absent or ambiguous anchor, missing
detector, skipped mutation, or survivor is a failure. See the
[testing strategy](../testing/strategy.md) for the automated, scratch-machine,
and fresh-VM evidence boundaries.

[`tests/check-structure.sh`](../../tests/check-structure.sh) checks the reviewed
dependency map, duplicate/unreachable functions, dynamic-entrypoint allowlist,
and representative reverse edges. It is a conservative Bash text check, not a
claim to be a complete shell parser.
