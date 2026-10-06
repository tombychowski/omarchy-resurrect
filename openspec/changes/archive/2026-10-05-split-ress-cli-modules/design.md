# Design

## Context

See [proposal.md](proposal.md) for motivation. Today `bin/ress` contains bootstrap and dispatch, shared configuration/output/locking helpers, vault capture and restore, verification and utility commands, profile sharing, registry persistence, resource inspection, and loadout lifecycle operations in one 5,224-line Bash script.

The split must preserve the properties that currently come from one process and one authoritative CLI: global option handling, file-descriptor locks, cleanup traps, resumable state, consent decisions, accumulated failure state, strict-shell behavior, and exact stdout/stderr and exit-status semantics. `Service.qml` resolves `bin/ress` relative to the installed plugin, and `ress link` may invoke that entrypoint through a symlink.

The files are installed together as an Omarchy plugin repository. There is no packaging manifest that copies an isolated executable, so tracked modules under `lib/ress/` travel with the entrypoint.

## Goals / Non-Goals

**Goals:**

- Give each major CLI domain an explicit file owner and a documented dependency direction.
- Keep the executable, process, command surface, persistent formats, safety boundaries, and consumer output unchanged.
- Make module loading deterministic, relocation-safe, silent on stdout, and testable.
- Preserve the existing function bodies wherever possible so regressions can be attributed to extraction and loading rather than simultaneous redesign.
- Make future command and resource work easier to place without forcing vault and loadout representations into one abstraction.
- Keep architecture, local file headers, repository guidance, and automated evidence synchronized with the resulting layout.

**Non-Goals:**

- Rewriting the CLI in another language or launching a subprocess per module.
- Creating a plugin API, dynamic command discovery, lazy loading, or third-party extension mechanism.
- Introducing a generic resource-adapter framework in the same change.
- Renaming public commands, changing options or output, moving state, changing schemas, or altering panel behavior.
- Refactoring function internals beyond the minimal adjustments required for explicit module ownership and loading.

## Decisions

### 1. Retain one public executable and one Bash process

`bin/ress` remains executable and owns:

1. strict-shell activation;
2. symlink-aware resolution of the plugin root;
3. explicit module sourcing;
4. cleanup-trap installation;
5. global option parsing and configuration loading;
6. usage text and command dispatch.

All commands continue to run in that process. Sourced modules share the existing shell state, file descriptors, arrays, and exit behavior.

This preserves the panel and PATH integration and avoids serializing internal state between subprocesses. A subprocess-per-command or executable-per-command layout was rejected because it would make locks, traps, confirmation state, and accumulated operation outcomes new interfaces rather than a mechanical refactor.

### 2. Use an explicit, layered module inventory

The target layout is:

```text
bin/ress
lib/ress/
  core.sh
  safety.sh
  vault/
    common.sh
    backup.sh
    restore.sh
    verify.sh
    commands.sh
  loadout/
    registry.sh
    profile.sh
    resources.sh
    share.sh
    lifecycle.sh
    apply.sh
```

Responsibilities are:

| File | Owns |
|---|---|
| `bin/ress` | root resolution, ordered loading, trap installation, global parsing, usage, dispatch |
| `core.sh` | constants, configured paths, output/protocol primitives, config loading/saving, generic helpers, locks, temporary-state declarations and cleanup |
| `safety.sh` | shared input validators, terminal sanitization, source normalization, credential stripping, pinned Git retrieval, and web-app argument parsing |
| `vault/common.sh` | vault selection, Git/manifest helpers, schema-compatible manifest lookup, and vault initialization primitives |
| `vault/backup.sh` | category capture, secret scanning used by backup, manifest writing, backup orchestration, and push |
| `vault/restore.sh` | restore progress, previews, AUR and service consent, category replay, and restore orchestration |
| `vault/verify.sh` | machine verification, explicit scanning, and deferred unit enablement |
| `vault/commands.sh` | status, init, settings, secrets configuration, link, doctor, and diff commands |
| `loadout/registry.sh` | registry schema validation, loading, atomic saving, revision checks, and operation journal primitives |
| `loadout/profile.sh` | source fetching, profile normalization/digests/identity, and normalized profile resource conversion |
| `loadout/resources.sh` | live resource inspection and the guarded install/remove/theme-effect operations shared by apply and lifecycle commands |
| `loadout/share.sh` | share-candidate discovery, catalog construction, selective export validation, and profile/README rendering |
| `loadout/lifecycle.sh` | loadout/resource queries, drift checking, recovery, repair, update, and removal orchestration |
| `loadout/apply.sh` | legacy apply compatibility, apply planning, claim registration/outcomes, and apply orchestration |

`bin/ress` lists every module path literally and sources them in dependency order. It does not use a filesystem glob. Modules never source one another; this keeps the complete runtime composition visible in one place and turns a missing file into an immediate startup failure.

The intended dependency direction is:

```text
bin/ress
  --> core
  --> safety
  --> vault common --> vault operations
  --> loadout registry/profile/resources --> share/lifecycle/apply
```

Vault and loadout orchestration may use `core.sh` and `safety.sh`. Shared loadout operations flow through registry/profile/resource owners rather than duplicating their rules. Vault and loadout remain separate domains: neither imports or reinterprets the other's persistent format.

### 3. Keep sourcing declarative and side-effect free

Module top level may declare constants, arrays, defaults, and functions. It must not parse arguments, acquire locks, install traps, access the network, mutate machine or persistent state, or write output merely because it was sourced. The entrypoint installs the single cleanup trap after every module loads.

Each module begins with a short header that states:

- its responsibility;
- the modules it depends on;
- significant global state it owns, reads, or updates; and
- the commands or workflows that use it.

These headers are local navigation aids. The durable relationship map lives in `docs/architecture/cli-modules.md` to avoid duplicating extensive architecture prose across source files.

### 4. Centralize globals without pretending Bash enforces privacy

Shared runtime flags and temporary paths remain process globals, but their declarations move to `core.sh`. Domain state such as restore progress/failures, registry revision/document, and apply/profile work paths is declared by the owning module and reset at the same lifecycle points as today.

The design does not add getters or namespace every existing function during the mechanical move. Bash cannot enforce module privacy, and a mass rename would obscure behavioral comparison. Ownership is instead made explicit through file placement, headers, the architecture map, and review/test rules. Later cleanup may introduce narrower interfaces as a separate change.

### 5. Preserve symlink and installed-plugin resolution

The symlink-following `self_dir` logic stays in `bin/ress`. It resolves the real `bin` directory before deriving the plugin root and sourcing `lib/ress/...`. Module files do not derive the repository root from their own `BASH_SOURCE`, because that value changes per sourced file.

A missing or unreadable required module fails before configuration loading or mutation and reports the problem on stderr. Module loading emits nothing on stdout, preserving JSON and porcelain purity from process start.

### 6. Separate mechanical extraction from later abstraction

The implementation moves functions and declarations into their assigned files with semantic edits limited to the loader, path ownership, trap placement, and tests. In particular, the change does not consolidate vault categories and loadout resources behind a new registry or adapter API.

The alternative—designing a resource framework while splitting—was rejected because vault categories include private configuration and encrypted secrets, while loadouts deliberately expose only constrained shareable definitions. Combining those concepts would blur an existing trust boundary and make regressions harder to attribute.

### 7. Expand automated evidence before relying on the split

The test runner syntax-checks `bin/ress` and every tracked production module. Existing cases continue invoking only the public entrypoint.

Focused coverage proves:

- direct repository invocation loads all required modules;
- invocation through the `ress link`-style symlink resolves the same modules;
- a relocated plugin checkout still resolves its own `defaults/` and `lib/ress/` trees;
- a missing module fails before command execution without contaminating machine-readable stdout; and
- help/version/status and representative JSON/porcelain commands remain byte- and status-compatible where their outputs are deterministic.

The mutation runner accepts an explicit production-relative target for each mutation and syntax-checks the complete production Bash set after mutation. A missing anchor, duplicate/ambiguous target, parse failure, surviving mutation, or skipped mutation remains a failure of mutation evidence rather than being silently ignored.

The runner establishes one clean full-suite baseline, then runs each mutation's
explicitly mapped detector case. Mutation evidence requires that the injected
fault make its detector red; rerunning unrelated integration cases for every
fault does not strengthen that evidence and would multiply a several-minute
suite into hours. The mutation-runner self-test may focus its baseline only when
using a sentinel that selects no mutations; real full and name-filtered sweeps
cannot narrow the clean baseline.

The full suite and `openspec validate --all --strict` remain the completion gates. Because the change does not alter real package, service, theme, panel-rendering, or machine-state semantics, it creates no new real-machine or fresh-VM evidence boundary.

### 8. Document both the architecture and how to extend it

Create `docs/architecture/cli-modules.md` as the authoritative implementation map. It contains:

- the startup and dispatch sequence;
- the dependency diagram and allowed dependency direction;
- a table for every production CLI file, its contents, globals, dependencies, and callers;
- rules for source-time behavior, stdout/stderr, traps, locking, and persistent-state ownership;
- walkthroughs for adding a command, vault category, or loadout resource;
- the tests and documentation layers that must change with each kind of addition; and
- the boundary between shared safety primitives and the distinct vault/loadout representations.

Update `docs/index.md` to link the new document, `docs/architecture/system-overview.md` to describe the modular CLI without duplicating the file map, `docs/testing/strategy.md` to describe module syntax/loading/mutation evidence, `README.md` to remove the single-file claim while retaining the no-QML-dependency message, and `AGENTS.md` to identify `bin/ress` plus `lib/ress/` as the authoritative CLI implementation.

Contracts, workflow instructions, OpenSpec main specs, and panel semantics do not change. They should not be edited merely to create churn; the architecture document links to those layers where their guarantees constrain module ownership.

An ADR is not required: this reorganizes one component without changing a trust boundary, external format, authority owner, runtime dependency, or operational mechanism. The architecture documentation is the appropriate durable home.

## Risks / Trade-offs

- **Source-order or unbound-global regressions** -> Keep declarations with explicit owners, source a literal topological list, syntax-check every file, and run commands only after all modules load.
- **A module emits output during sourcing and corrupts JSON/porcelain** -> Prohibit source-time output and add machine-readable startup coverage, including missing-module failure behavior.
- **Symlinked `ress` cannot find modules** -> Retain root resolution in the entrypoint and test direct, symlinked, and relocated invocations.
- **The mutation suite silently stops modifying extracted code** -> Make the target file explicit per mutation and fail on absent anchors or unparsed production files.
- **Moving code and redesigning it together hides regressions** -> Limit this change to extraction and loader/test/documentation adjustments; schedule API cleanup separately.
- **Global shell state still permits accidental cross-module coupling** -> Document ownership and dependency rules now; accept that full encapsulation is unavailable without a language/process boundary.
- **More files increase navigation cost** -> Keep the inventory bounded to cohesive domains, maintain one architecture map, and avoid one-file-per-function fragmentation.
- **An incomplete installed tree leaves the entrypoint without modules** -> Fail closed before configuration or mutation; plugin installation and Git updates continue to deliver the tracked tree as one version.

## Migration Plan

1. Harden syntax and mutation infrastructure so it can address multiple production files.
2. Add the explicit loader and extract core/safety code, keeping `bin/ress` as the only invocation path.
3. Extract vault modules and run focused backup, restore, protocol, hostile-input, verification, and status cases.
4. Extract loadout modules and run focused registry, sharing, apply, query, checking, repair, update, removal, and round-trip cases.
5. Add symlink/relocation/missing-module coverage and reconcile all architecture, repository, and testing documentation.
6. Run the complete test suite and strict OpenSpec validation, then review the diff specifically for command/output/state changes.

There is no persistent-state or data migration. Rollback is a repository revert to the single-file implementation; vaults, profiles, configuration, registry state, and panel integration remain compatible in either direction.
