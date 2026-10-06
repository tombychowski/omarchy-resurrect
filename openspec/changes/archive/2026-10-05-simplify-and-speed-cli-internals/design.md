# Design

## Context

See `proposal.md` for motivation. The mechanical module split deliberately preserved one-process globals and function bodies. As a result, source order is deterministic but ownership is not yet acyclic: loadout workflows call AUR functions owned by vault restore, resource/lifecycle modules call apply-owned outcome/planning functions, core cleanup names domain temporary paths, and registry-heavy paths repeatedly spawn jq and pacman processes. The full suite is isolated but sequential and currently takes roughly 339 seconds on the development machine.

## Goals / Non-Goals

**Goals:**

- Make module dependencies follow the documented ownership graph.
- Remove proven unreachable code and make future dead/reverse dependencies detectable.
- Reduce per-resource subprocess work while preserving live inspection truth.
- Shorten feedback time without weakening full-suite or mutation evidence.

**Non-Goals:**

- Change CLI/protocol behavior, persistent formats, consent, or safety policy.
- Create a generic representation shared by private vault categories and public loadout resources.
- Rewrite the CLI in another language, create independently executable modules, or add a runtime dependency.
- Optimize module startup through lazy loading; measured startup cost does not justify weakening complete-tree validation.

## Decisions

### 1. Remove dead code before moving live ownership

Delete the unreachable legacy apply function, unused generic JSON helper, and unused locals only after focused tests prove current tracked apply and legacy whole-machine share behavior. This establishes a smaller call graph before functions move and prevents historical naming from being mistaken for compatibility requirements.

### 2. Introduce neutral machine operations and loadout planning owners

Create a neutral machine package module for package inventory, repository/AUR probing, AUR consent, and package installation helpers shared by vault restore and loadout workflows. It owns no vault or registry representation.

Create a loadout planning module for definition compatibility and apply/update/repair plan construction. Move claim/outcome registry transformations into the registry owner. Apply and lifecycle remain orchestration; resources owns external resource adapters. This direction is preferred over allowing documented reverse dependencies because file placement should predict what policy a function may change.

### 3. Make cleanup registration generic but bounded

Core owns the one EXIT trap and a registry of ress-created temporary paths. Domain modules register a path only after successful `mktemp`; cleanup accepts only paths under approved temporary or operation-specific parents and distinguishes files from directories. This removes domain globals from core without turning cleanup into an arbitrary recursive-delete API.

### 4. Centralize configuration schema metadata

Represent persisted keys, defaults, allowed choices/types, and stable serialization order in one core-owned schema. Loading ignores unknown keys and preserves safe fallback behavior for malformed hand edits; `set`, save, and status conversion consult the same metadata. QML remains a consumer of the documented config file and CLI settings.

### 5. Build one live observation snapshot per command

Before planning/checking multiple resources, collect installed package names once, active theme once, and registry indexes once. Resource inspection consumes the snapshot while retaining per-plugin/theme Git evidence where individual filesystem state genuinely differs. The snapshot lives only for one command, so it cannot become stale persistent truth.

Plans and views accumulate newline-delimited JSON records or Bash arrays and assemble them in one jq pass instead of repeatedly copying growing JSON arrays. Reusable, substantial pure filters may move to checked `lib/ress/jq/*.jq` files; small single-owner filters remain beside their shell caller.

### 6. Split restore by policy ownership, not size alone

Extract package operations first. Then separate restore progress/journal and preview/consent from category replay only when each resulting module has a clear owner and acyclic dependencies. Category capture/restore/verify may share validated inspection primitives, but their private vault and public loadout serializations remain distinct.

### 7. Add structural and performance evidence

Extend module tests with an allowed-dependency map and an explicit allowlist for public/dynamic entrypoints such as `capture_$category` and `restore_$category`. Add loadout fixtures that assert package inventory command counts and output equality at representative size rather than enforcing environment-sensitive wall time.

The test runner records case duration and supports bounded parallel jobs while retaining result order and one isolated sandbox per case. Fixed global temporary assertions are made sandbox-specific first. Mutation runs keep a clean full baseline and isolated mutations; parallel mutation execution is not required by this change.

ShellCheck and formatting checks are development/CI gates, not runtime dependencies. If the repository CI image cannot provide them reproducibly, tasks record that limitation rather than making local command availability a false guarantee.

## Risks / Trade-offs

- **[Moving functions and optimizing them together obscures regressions]** -> Stage dead-code removal, ownership moves, then batching, running focused tests and reviewing behavior-preserving diffs after each stage.
- **[Snapshot inspection hides mid-command external changes]** -> Snapshot only stable batch facts such as installed package names; re-read mutation-sensitive resources immediately before guarded external actions.
- **[Parallel tests reveal hidden shared state]** -> Make every fixture sandbox-relative, provide `--jobs 1`, and compare sequential/parallel totals before changing the default.
- **[A generic cleanup registry broadens deletion risk]** -> Register only paths returned by controlled creation helpers and validate approved parent prefixes before recursive removal.
- **[Static call-graph checks misread Bash dynamic dispatch]** -> Keep a small reviewed allowlist and treat the check as architecture evidence alongside composed CLI tests, not as a parser-proof guarantee.

## Migration Plan

1. Establish focused behavior and call-count baselines; add per-case timing without changing execution order.
2. Remove dead code and update mutation/static ownership evidence.
3. Extract neutral package operations, loadout planning, registry outcomes, bounded cleanup registration, and centralized configuration schema in small verified moves.
4. Batch live observation and JSON assembly, comparing human/JSON/porcelain output and exit status against fixtures.
5. Split remaining oversized restore responsibilities where the resulting dependency graph is simpler.
6. Enable bounded parallel suite execution after eliminating shared fixtures; add CI static checks where reproducible.
7. Reconcile architecture/testing documentation, run the full suite in sequential and parallel modes, run the mutation sweep, and run strict OpenSpec validation.

There is no persistent-state migration. Each stage can be reverted independently because external formats and interfaces remain unchanged.
