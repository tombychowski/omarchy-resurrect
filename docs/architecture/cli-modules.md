# CLI module architecture

The Montage CLI is one Bash program distributed across a public entrypoint and
sourced implementation modules. [`bin/mntg`](../../bin/mntg) remains the only
executable interface: the panel, scheduler, tests, and PATH symlink invoke it,
and it remains authoritative for machine inspection, validation, mutation,
persistent state, and consumer output.

Splitting the implementation does not create a plugin API or separate command
processes. Every module runs in one shell process and therefore shares strict
mode, functions, variables, locks, traps, and exit status.

## Startup and dispatch

For every invocation, `bin/mntg`:

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
bin/mntg
  +--> core.sh --> safety.sh
  +--> repository/common.sh --> registry.sh / transaction.sh / reader.sh
                              --> commands.sh
  +--> machine/packages.sh
  +--> vault/common.sh --> backup.sh / restore-state.sh / restore-preview.sh
                         --> restore.sh / verify.sh / commands.sh
  +--> loadout/registry.sh / profile.sh / resources.sh / planning.sh
                              +--> share.sh / lifecycle.sh / apply.sh
  +--> port/{common,adapter,inspect,import,export,commands}.sh
                     --> port/adapters/ress_v1/{format,translate}.sh
```

This diagram groups ownership; the literal source order remains the list in
`bin/mntg`. All modules load before dispatch, so runtime function calls may
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
| [`bin/mntg`](../../bin/mntg) | Root resolution, required-module loading, cleanup-trap installation, usage, global option parsing, config-load timing, dispatch | Invoked by people, QML, the scheduler, and tests; loads every row below |
| [`lib/montage/core.sh`](../../lib/montage/core.sh) | Versions and format constants, derived paths, ordered configuration schema and `CFG`, output, flags, bounded temporary creation/cleanup, and locks | Foundation for every module; expects `PLUGIN_DIR` from the entrypoint |
| [`lib/montage/safety.sh`](../../lib/montage/safety.sh) | Untrusted-name/schema/URL validators, portable profile-v1 structural validation, terminal sanitization, source normalization, credential stripping, pinned Git retrieval, Desktop Entry web-app parsing | Shared by vault, loadout, and compatibility code; depends on core output and flags |
| [`lib/montage/repository/common.sh`](../../lib/montage/repository/common.sh) | Native `montage.json` schema, stable repository identity, kind, and timestamp validation | Foundation for loadout and vault repositories; depends on shared safety primitives but owns no domain payload |
| [`lib/montage/repository/registry.sh`](../../lib/montage/repository/registry.sh) | Named local repository configuration, expected identity binding, sanitized remote metadata, serialized persistence | Repository commands and later panel consumers; owns `repositories.json` and its dedicated configuration lock |
| [`lib/montage/repository/transaction.sh`](../../lib/montage/repository/transaction.sh) | Identity-scoped locks, same-filesystem staging, recoverable publication journals, clean-tree checks, content-changing commits | Shared by repository writers; does not decide loadout or vault validity |
| [`lib/montage/repository/reader.sh`](../../lib/montage/repository/reader.sh) | Contained live-control lookup, bounded Git ref resolution, stable-id profile lookup, isolated Git-object materialization and link containment | Shared by repository queries and historical consumers; never checks out over a configured working tree |
| [`lib/montage/repository/sync.sh`](../../lib/montage/repository/sync.sh) | Fetch-only history classification, optional visibility evidence, validated fast-forward pull, and ordinary non-forced push | Shared by both native repository kinds; never resolves divergence automatically |
| [`lib/montage/repository/commands.sh`](../../lib/montage/repository/commands.sh) | Human, versioned JSON, and porcelain list, show, validate, configure, remove, and synchronization surfaces | `repository`; the panel-facing boundary for repository configuration and health |
| [`lib/montage/machine/packages.sh`](../../lib/montage/machine/packages.sh) | Installed-package and active-theme snapshots, repository/AUR probing, AUR consent, package installation helpers | Neutral machine operations; owns no vault, profile, or registry representation |
| [`lib/montage/vault/common.sh`](../../lib/montage/vault/common.sh) | Selected `VAULT`, Git helpers, current/legacy manifest lookup, safe manifest JSON, vault initialization | All vault modules; depends on core and safety policies |
| [`lib/montage/vault/backup.sh`](../../lib/montage/vault/backup.sh) | Category capture, backup credential scan, manifest writing, commit and push | `backup`, and scan reporting shared with `scan`; depends on core, safety, vault common |
| [`lib/montage/vault/restore-state.sh`](../../lib/montage/vault/restore-state.sh) | Restore progress, failure, partial-result, first-contact and unit-choice state | Restore preview and orchestration; depends on core |
| [`lib/montage/vault/restore-preview.sh`](../../lib/montage/vault/restore-preview.sh) | Restore-wide executable-content/package/plugin preview and unit-decision interpretation | Restore orchestration; depends on core, safety, machine operations, vault common and restore state |
| [`lib/montage/vault/restore.sh`](../../lib/montage/vault/restore.sh) | Private-vault category replay, service consent execution, resumable orchestration | `restore`; depends on core, safety, machine operations, vault common, restore state and preview |
| [`lib/montage/vault/verify.sh`](../../lib/montage/vault/verify.sh) | Machine comparison, explicit scan, deferred unit enablement | `verify`, `scan`, `enable-units`; uses capture/restore parsing rules rather than inventing alternatives |
| [`lib/montage/vault/commands.sh`](../../lib/montage/vault/commands.sh) | Status, initialization, settings, secrets setup, PATH link, doctor, and diffs | `status`, `init`, `set`, `secrets`, `link`, `doctor`, `diff`; depends on core, safety, vault common, while `status` consumes loadout-owned query functions after startup |
| [`lib/montage/loadout/registry.sh`](../../lib/montage/loadout/registry.sh) | Registry validation/persistence, command-local indexes, operation journal, claim registration and outcomes | All tracked-loadout commands; owns registry state, schema, indexes and transitions |
| [`lib/montage/loadout/profile.sh`](../../lib/montage/loadout/profile.sh) | Fetch, normalization, digest and local identity, normalized profile-to-resource conversion | `share`, `update`, `apply`; depends on core and safety |
| [`lib/montage/loadout/resources.sh`](../../lib/montage/loadout/resources.sh) | Snapshot-backed inspection plus immediate live rereads for guarded install, remove, and theme effects | `share`, `check`, `repair`, `update`, `remove`, `apply`; depends on machine observations and registry-owned outcomes |
| [`lib/montage/loadout/planning.sh`](../../lib/montage/loadout/planning.sh) | Definition compatibility and apply/update/repair plan construction | Apply and lifecycle orchestration; depends on profile, registry indexes and resource inspection |
| [`lib/montage/loadout/share.sh`](../../lib/montage/loadout/share.sh) | Candidate discovery, catalog, selection and withdrawal validation, profile/README rendering | `share`; depends on profile, registry, and live resource inspection |
| [`lib/montage/loadout/lifecycle.sh`](../../lib/montage/loadout/lifecycle.sh) | Queries, recovery, checking, repair, update, claim release and removal | `loadout`, `resource`; depends on registry/profile/resources |
| [`lib/montage/loadout/apply.sh`](../../lib/montage/loadout/apply.sh) | Apply orchestration | `apply`; depends on machine operations, registry/profile/resources/planning and lifecycle handoff |
| [`lib/montage/port/common.sh`](../../lib/montage/port/common.sh) | Format-neutral report construction/refusal/completion, destination isolation, safe Git revision materialization, exact loss matching, staged-directory publication, decision-field merging, and human/JSON/porcelain projection | Shared port engine; contains no foreign-format names or schema rules |
| [`lib/montage/port/adapter.sh`](../../lib/montage/port/adapter.sh) | Generic adapter context, descriptor selection, and one literal `(format, callback)` dispatch matrix | Shared port engine; the only format-aware shared module and never constructs a function name from input |
| [`lib/montage/port/inspect.sh`](../../lib/montage/port/inspect.sh) | Inspection/report orchestration, destination planning, chronological history iteration, compatibility selection, and mutation planning | Calls foreign semantics only through `port/adapter.sh` and uses the envelope-neutral repository reader |
| [`lib/montage/port/import.sh`](../../lib/montage/port/import.sh) | Dry run, format decisions, confirmation, native repository selection/setup, locks, staging, validation, commits, compatible-history publication, and output | Owns all import lifecycle; invokes an adapter only to validate or translate one foreign tree |
| [`lib/montage/port/export.sh`](../../lib/montage/port/export.sh) | Exact loss gate, native loadout/backup selection, format decisions, confirmation, staging, validation, publication, and output | Owns all export lifecycle; invokes an adapter only to translate and validate foreign output |
| [`lib/montage/port/adapters/ress_v1/format.sh`](../../lib/montage/port/adapters/ress_v1/format.sh) | Frozen Ress v1 names, schemas, artifact detection, inspection facts, shared self-plugin discovery/decisions, loss codes, and format-only option callbacks | Ress v1 semantics only; owns no Git traversal, native transaction, staging, publication, or output |
| [`lib/montage/port/adapters/ress_v1/translate.sh`](../../lib/montage/port/adapters/ress_v1/translate.sh) | Ress v1-to-native and native-to-Ress semantic transformations plus staged Ress validation | Operates only on paths prepared and passed by the shared engine |
| [`lib/montage/port/commands.sh`](../../lib/montage/port/commands.sh) | Format-neutral inspect, plan, import, and export parsing plus top-level `port` routing | `port`; refuses unsupported identifiers before an adapter reads a source and delegates only format-specific options through the callback matrix |

Vault modules and loadout modules may share safety primitives, but neither reads
or reinterprets the other's persistent format. A private vault can represent
selected files and encrypted secrets; a public loadout intentionally cannot.
The repository layer owns only the shared container identity, registry,
transaction, and read boundaries. Loadout modules continue to own portable
profile semantics and vault modules continue to own backup payload semantics;
neither domain may make the repository layer interpret the other's leaf data.
See [Repository format](../contracts/repository-format.md),
[Vault format](../contracts/vault-format.md), [Loadout profile](../contracts/loadout-profile.md),
and [Applied-loadout registry](../contracts/loadout-registry.md).

Port modules follow a parallel boundary: the shared port engine owns lifecycle
invariants but cannot recognize or translate a foreign artifact, while each
adapter owns foreign semantics but cannot perform Git traversal, native
selection/transactions, staging, confirmation, publication, or output. See
[Port adapter architecture](port-adapters.md).

## Source-time rules

A module may define functions, constants, arrays, and initial in-memory state.
Merely sourcing it must not:

- parse command-line arguments or dispatch a command;
- install or replace a trap;
- acquire a lock or create its marker;
- inspect or mutate a vault, registry, profile, or machine resource;
- contact a remote; or
- write stdout or stderr.

The entrypoint installs `montage_cleanup` once all required modules have loaded.
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
| Repository envelope constants and validation | `repository/common.sh` | Shared container identity only; does not authorize a payload or cleanup action |
| Configured repository document and revision | `repository/registry.sh` | Named paths remain bound to the expected repository id and kind; writes use the configuration lock |
| Repository lock, staging, journal, and history-reader paths | `repository/transaction.sh` and `repository/reader.sh` | Identity-scoped operational state below the Montage state root; core still owns bounded temporary cleanup |
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
the dispatch arm and usage text to `bin/mntg`, and keep all inspection and
mutation inside the CLI. Add focused human/JSON/porcelain and exit-status tests
as applicable. Update the file table when ownership changes; update contracts or
OpenSpec only when observable behavior changes.

### Add a setting

Add the key once to core's ordered `CONFIG_KEYS`, `CONFIG_DEFAULTS`, and
`CONFIG_TYPES`, plus `CONFIG_CHOICES` when constrained. Loading, validation,
stable saving, and status conversion must use that metadata rather than a
second key list. Update the config/CLI contract and panel presentation as
needed, but keep QML a consumer that writes only through `mntg set`.

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

### Add repository behavior

Keep envelope and identity rules in `repository/common.sh`, named path and
remote configuration in `repository/registry.sh`, mutation mechanics in
`repository/transaction.sh`, and containment or historical reads in
`repository/reader.sh`. User and panel queries belong in
`repository/commands.sh`. A loadout or vault module supplies its own complete
payload validator before publication; shared repository code must not infer
domain validity from a directory name or a Git commit alone.

### Add a port format

Do not copy an existing adapter wholesale. Add a new bounded directory under
`port/adapters/<format-id>/`, register its descriptor and literal callback
cases in `port/adapter.sh`, and reuse `port/common.sh` for destination validation,
history materialization, loss acceptance, publication, and report output. The
adapter supplies its own schema validators, translators, fixtures, loss codes,
and compatibility evidence. Update the port protocol and format workflow only
when the shared envelope or observable behavior changes. The complete checklist
and dependency rules are in [Port adapter architecture](port-adapters.md).

## Evidence for module changes

[`tests/run.sh`](../../tests/run.sh) syntax-checks the entrypoint and every
`.sh` file below `lib/montage/` before running cases. Existing cases invoke the
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
