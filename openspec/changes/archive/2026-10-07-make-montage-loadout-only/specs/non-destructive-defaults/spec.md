# Spec Delta

## REMOVED Requirements

### Requirement: No Implicit Removal

**Reason**: The requirement combines vault restore and Loadout behavior under a product-wide backup-era boundary.

**Migration**: The Loadout no-implicit-removal guarantee moves to `loadout-preservation`; restore scenarios are removed.

### Requirement: Backup Before Replacement

**Reason**: Replacement files and restore replay are removed with machine Backup/Restore.

**Migration**: Loadout resource mutation follows resource-specific provenance and preservation rules rather than copied-file restore suffixes.

### Requirement: Installation Is Additive

**Reason**: The mixed restore/loadout statement is replaced by an explicit Loadout application guarantee.

**Migration**: Additive apply behavior moves without weakening to `loadout-preservation`.

### Requirement: Explicit Loadout Removal Is Narrowly Scoped

**Reason**: The behavior remains required but belongs in the dedicated Loadout preservation capability.

**Migration**: Claims, pre-existing-resource protection, changed-resource decisions, and final-claim cleanup move to `loadout-preservation` and continue to be elaborated by `loadout-reconciliation`.

### Requirement: Cleanup Does Not Infer Dependency Ownership

**Reason**: The behavior remains required but belongs in the dedicated Loadout preservation capability.

**Migration**: Dependency, application-data, cache, and configuration preservation moves without weakening to `loadout-preservation`.
