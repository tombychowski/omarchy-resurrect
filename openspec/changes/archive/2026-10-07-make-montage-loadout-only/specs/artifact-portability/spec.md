# Spec Delta

## REMOVED Requirements

### Requirement: Port Formats Are Explicitly Selected

**Reason**: Montage no longer exposes a general multi-format import/export product surface. The only retained foreign input is the bounded Ress v1 loadout migration capability.

**Migration**: Use the explicit Ress loadout inspect/import workflow defined by `ress-loadout-migration`.

### Requirement: Port Lifecycle Safety Is Format Neutral

**Reason**: History translation, native vault selection, export, and multi-artifact publication are removed, so the broad format-neutral lifecycle is no longer a durable product capability.

**Migration**: Preserve source isolation, staging, validation, exact loss decisions, confirmation, and atomic library publication inside the focused Ress loadout migration boundary.

### Requirement: Port Reports Use One Extensible Envelope

**Reason**: The extensible multi-operation port envelope exceeds the remaining import-only, single-format product boundary.

**Migration**: Consumers use the versioned Ress loadout migration result documented by the CLI protocol.

### Requirement: New Formats Remain Isolated

**Reason**: Supporting future foreign artifact formats is no longer an active Montage capability.

**Migration**: A future format would require a separate product decision and OpenSpec change rather than inheriting an unused generic adapter promise.
