# Principles

These principles constrain product and engineering decisions. The linked OpenSpec capabilities own current observable guarantees; statements marked as design guidance describe how to evaluate future work.

## The user owns the state

Vaults, profiles, configuration, and progress state remain inspectable local files. Network storage is optional, and remote credentials are never a prerequisite for using Montage. This is design guidance reflected by the vault-capture and loadout-sharing capabilities.

## Use the least-powerful representation

Capture declarative state instead of executable artifacts whenever possible: package names instead of install scripts, service names instead of `.wants/` symlink farms, and web-app fields instead of copied launchers. If a safe representation is unavailable, omit and report the item. See vault-capture and loadout-sharing.

## Consent follows power

General overwrite confirmation does not authorize running AUR build instructions or enabling persistent user services. Those actions receive separate, informed decisions because they execute code now or later. See explicit-execution-consent.

## Preserve before replacing

Restore and loadout application are additive by default. They do not infer deletion from absence, and existing files are retained before replacement. See non-destructive-defaults.

## Interruption is ordinary

Long operations should expose progress and preserve enough state to continue safely. Declining gated work is neither failure nor completion; it remains available later. See resumable-restore and explicit-execution-consent.

## Secrets take an explicit encrypted path

Credential-shaped files are excluded from ordinary capture, captured content is scanned before commit, and selected secrets travel only through an opt-in encrypted bundle. Convenience must not create a plaintext credential path. See credential-protection.

## Report truth, including omissions

Montage should name what it captured, skipped, refused, deferred, or cannot reconstruct. Verification must distinguish a missing restorable item from an inventory item that never could travel. See vault-capture, machine-verification, and cli-consumer-protocol.

## The CLI is authoritative

The CLI owns machine inspection, validation, mutation, and stable consumer output. The panel presents that state and dispatches commands; it does not independently reinterpret the vault. See cli-consumer-protocol and panel-integration.

## Compatibility is explicit

External formats have versions and defined migration boundaries. Unrecognized or hostile versions are refused before mutation rather than guessed at. See schema-compatibility.

Interoperability never creates shared live ownership. Legacy artifacts are
inspected and ported between separate paths, with explicit loss and self-plugin
decisions. Native repositories, history, locks, configuration, and applied
ownership remain Montage-only.

## Stay intentionally narrow

Montage reconstructs Omarchy setup state. It should not grow into a general data-backup system, arbitrary script runner, secrets manager, or remote orchestration service. This is design guidance derived from the [vision](vision.md).
