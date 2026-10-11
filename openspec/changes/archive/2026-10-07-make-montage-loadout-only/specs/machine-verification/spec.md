# Spec Delta

## REMOVED Requirements

### Requirement: Verification Reflects Restorable State

**Reason**: Comparing a machine with restorable vault contents is removed with Backup/Restore.

**Migration**: Use `mntg loadout check` to compare applied Loadout desired state with supported current resources.

### Requirement: Verification Supports Structured Output

**Reason**: `mntg verify` and its backup-category result are removed.

**Migration**: Loadout and resource queries continue to provide structured item collections through `cli-consumer-protocol`.

### Requirement: Status Reports Capture State Safely

**Reason**: Backup availability, freshness, category configuration, and manifest data no longer belong in status.

**Migration**: Loadout-only status and unavailable-state behavior are defined by `cli-consumer-protocol` and `loadout-reconciliation`.

### Requirement: Applied Loadout Health Is Verifiable

**Reason**: The behavior remains required but is already owned more coherently by `loadout-reconciliation`.

**Migration**: `mntg loadout check`, structured resource health, and nonzero unhealthy outcomes remain under `loadout-reconciliation`.

### Requirement: Loadout Status Survives Optional State Problems

**Reason**: The surviving no-fabrication behavior moves to loadout attention and the loadout-only status protocol.

**Migration**: Invalid optional registry or repository state is reported as unavailable or invalid by `loadout-reconciliation` and `cli-consumer-protocol`.
