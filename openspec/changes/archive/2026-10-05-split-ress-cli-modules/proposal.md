# Proposal

## Why

The authoritative Bash CLI has grown to more than 5,200 lines in one file, so changes to vault capture and restore, loadout sharing and reconciliation, consumer protocols, and common safety helpers all meet in the same implementation unit. Splitting it along explicit ownership and dependency boundaries will make future work easier to locate and review without changing the CLI's behavior or authority.

## What Changes

- Keep `bin/ress` as the single public executable while reducing it to bootstrap, module loading, global option parsing, usage, and command dispatch.
- Extract the existing implementation mechanically into sourced Bash modules organized around shared runtime and safety concerns, resource operations, the private vault domain, and the shareable loadout domain.
- Preserve one Bash process and the existing CLI, JSON, porcelain, filesystem, locking, cleanup, consent, compatibility, and panel boundaries.
- Establish dependency and ownership rules for modules before pursuing later internal abstractions; this change does not introduce a generic resource framework.
- Extend syntax, loading, relocation/symlink, and mutation-test support so all production modules receive the same evidence currently applied to `bin/ress`.
- Add architecture documentation that maps every CLI file, its responsibilities, dependencies, shared-state use, loading order, and extension points, and reconcile existing repository guidance and testing documentation with the split implementation.

## Capabilities

### New Capabilities

None. This is an internal refactor and documentation change.

### Modified Capabilities

None. Existing observable requirements remain unchanged; `.openspec.yaml` declares `skip_specs: true` rather than inventing a behavioral delta.

## Impact

- **CLI implementation:** `bin/ress` and new modules under `lib/ress/`.
- **Automated evidence:** `tests/run.sh`, `tests/mutate.sh`, and focused module-loading and invocation coverage; the existing behavior suite remains authoritative.
- **Architecture and contributor documentation:** a new CLI-module architecture document plus updates to `docs/index.md`, `docs/architecture/system-overview.md`, `docs/testing/strategy.md`, `README.md`, and `AGENTS.md`.
- **Observable behavior and compatibility:** no intended changes to commands, options, output, exit status, protocols, schemas, state locations, vault/loadout formats, safety guarantees, or panel semantics. No contract, workflow, or main-spec behavior changes are proposed.
- **Dependencies and deployment:** no new runtime dependency; the plugin continues to install as one repository and the panel continues to invoke `bin/ress`.
