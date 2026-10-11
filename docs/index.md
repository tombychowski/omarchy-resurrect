# Montage documentation

Montage composes, shares, applies, and reconciles portable Omarchy loadouts.
Start with the [README](../README.md) for installation and common commands.

## Product direction

- [Vision](vision/vision.md) — the user problem, boundaries, and direction.
- [Principles](vision/principles.md) — durable safety and ownership constraints.
- [System overview](architecture/system-overview.md) — components, state, and trust boundaries.
- [Application identity](architecture/application-identity.md) — command, plugin id, XDG ownership, and Ress coexistence.
- [CLI modules](architecture/cli-modules.md) — exact module ownership and dependency direction.
- [Ress migration architecture](architecture/port-adapters.md) — the one frozen import-only boundary.

## Exact contracts

- [Loadout library repositories](contracts/repository-format.md)
- [Portable loadout profile](contracts/loadout-profile.md)
- [Applied-loadout registry](contracts/loadout-registry.md)
- [CLI consumer protocol](contracts/cli-protocol.md)

## Panel

- [Principles](panel/principles.md)
- [Status language](panel/status-language.md)
- [CLI integration](panel/cli-integration.md)
- [Keyboard workflow](panel/keyboard-workflow.md)
- [Settings](panel/settings.md)

## Workflows

- [Compose, share, and apply](workflows/share-apply.md)
- [Synchronize libraries](workflows/repository-sync.md)
- [Import one Ress v1 loadout](workflows/ress-portability.md)
- [Move from Ress to Montage](workflows/migrate-from-ress.md)

## Evidence and release

- [Testing strategy](testing/strategy.md)
- [Fresh-machine validation](testing/fresh-machine-validation.md)
- [Disposable Proxmox VM runbook](testing/disposable-vm-runbook.md)
- [Media inventory](media/README.md)
- [Marketplace release](release/marketplace.md)
- [Decision records](decisions/README.md)
- [OpenSpec](../openspec/)

## Authority

Vision explains why and where. Principles constrain decisions. Archived
OpenSpec main specs define observable behavior; an active change is proposed
truth until implemented and archived. Contracts own exact formats. Architecture
owns internal boundaries. Panel docs own language and interaction. Workflows
compose those layers. Tests record evidence, including explicit environment
limits. The README is the public landing page.

When those layers disagree, reconcile them in one change. Do not present
direction as shipped behavior or weaken consent, preservation, credential, or
compatibility guarantees to match an implementation discrepancy.
