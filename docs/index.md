# Montage documentation

Montage captures the reconstructible parts of an Omarchy machine and replays them safely. This index is the entry point for understanding the product, its guarantees, its interfaces, and the evidence behind them.

For installation and the most common commands, start with the [README](../README.md).

## Find what you need

### Understand the project

- [Vision](vision/vision.md) — the problem Montage exists to solve, its audience, boundaries, and direction.
- [Principles](vision/principles.md) — durable constraints used to evaluate changes.
- [System overview](architecture/system-overview.md) — components, data flow, persistent state, and trust boundaries.
- [Application identity and coexistence](architecture/application-identity.md) — plugin id, command, XDG ownership, linking, and side-by-side Ress installation.
- [CLI module architecture](architecture/cli-modules.md) — entrypoint loading, file ownership, dependency direction, shared state, and extension guidance.
- [Port adapter architecture](architecture/port-adapters.md) — shared conversion lifecycle, adapter responsibilities, report contract, and future-format checklist.

### Work with exact interfaces

- [Repository envelope](contracts/repository-format.md) — native `montage.json` identity, kinds, versions, and field bounds.
- [Vault format](contracts/vault-format.md) — the private Git vault, manifest, payloads, and compatibility.
- [Loadout profile](contracts/loadout-profile.md) — the constrained shareable `profile.json` format.
- [Applied-loadout registry](contracts/loadout-registry.md) — local desired state, provenance, claims, journaling, and cleanup authority.
- [Restore safety](contracts/restore-safety.md) — preview, consent, resumability, and preservation rules.
- [CLI protocol](contracts/cli-protocol.md) — JSON and porcelain surfaces for automation and the panel.

### Understand the panel

- [Panel principles](panel/principles.md) — the panel's role and UX guardrails.
- [Status language](panel/status-language.md) — how freshness and operation states are presented.
- [CLI integration](panel/cli-integration.md) — status refresh, command dispatch, progress, and terminal handoff.
- [Keyboard workflow](panel/keyboard-workflow.md) — row navigation, shortcuts, focus, and rendered evidence requirements.
- [Panel settings](panel/settings.md) — locked Montage repository configuration and the separate Ress port source.

### Follow a workflow

- [Back up and restore](workflows/backup-restore.md)
- [Share and apply a loadout](workflows/share-apply.md)
- [Synchronize repositories](workflows/repository-sync.md)
- [Port Ress v1 artifacts](workflows/ress-portability.md)
- [Migrate from Ress](workflows/migrate-from-ress.md)
- [Transport encrypted secrets](workflows/encrypted-secrets.md)

### Verify or change the project

- [Marketplace submission](release/marketplace.md) — independent listing metadata, lifecycle commands, and release asset names.
- [Testing strategy](testing/strategy.md) — automated, mutation, real-machine, and VM evidence.
- [Fresh-machine validation](testing/fresh-machine-validation.md) — the clean-Omarchy test and recording procedure.
- [Decision records](decisions/README.md) — when and how to record durable architectural choices.
- [OpenSpec](../openspec/) — behavioral specifications and active changes.

## Documentation authority

Each layer answers a different question:

1. **Vision** explains why the project exists and where it is headed. It is not a release claim.
2. **Principles** are durable product and engineering constraints.
3. **OpenSpec main specs** define observable product behavior. Active changes propose deltas; they are not shipped behavior until implemented and archived.
4. **Contracts** define exact external formats and consumer protocols.
5. **Architecture** explains the current internal structure and trust boundaries.
6. **Panel documentation** defines presentation semantics while taking machine state from the CLI.
7. **Workflows** explain supported journeys by referring to the normative layers above.
8. **Testing documentation** describes evidence, limitations, and manual validation.
9. **The README** is the public landing page, installation guide, and common-use reference.

When implementation, tests, specs, and contracts disagree, surface and reconcile the discrepancy in the same change. Current code is evidence of behavior, not permission to silently weaken a documented safety guarantee.

## Keeping documentation current

A behavior-changing proposal should name the affected OpenSpec capability, contract, workflow, panel language, and tests. Prefer links over duplicated rules. Put exact formats in contracts, observable guarantees in specs, implementation explanations in architecture, and commands for a user journey in workflows.

The [`media/` inventory](media/README.md) distinguishes current Montage release
captures from archived predecessor assets. The website under `site/` owns its
separate deployment assets and must not deploy material under `site/archive/`.
