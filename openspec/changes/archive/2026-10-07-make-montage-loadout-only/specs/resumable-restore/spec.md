# Spec Delta

## REMOVED Requirements

### Requirement: Restore Preview Before Mutation

**Reason**: Machine restore and backup selection are removed from Montage.

**Migration**: Loadout apply, repair, update, and removal retain their own preview and confirmation requirements.

### Requirement: Category Selection

**Reason**: Restore categories exist only for replaying machine backups.

**Migration**: Compose a constrained Loadout resource selection rather than selecting backup replay categories.

### Requirement: Resumable Progress

**Reason**: Repository/backup-bound restore progress is removed with machine restore.

**Migration**: Applied-loadout mutation journaling and resumability remain governed by `applied-loadouts` and `loadout-reconciliation`.

### Requirement: Dry-Run Fidelity

**Reason**: Restore dry run is removed with the restore command.

**Migration**: Loadout apply, repair, update, removal, repository synchronization, and Ress loadout migration retain operation-specific previews or dry runs.
