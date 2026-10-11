# Spec Delta

## REMOVED Requirements

### Requirement: A Vault Repository Represents One Machine Lineage

**Reason**: Vault repositories and machine lineage are removed from Montage.

**Migration**: Existing vault directories remain untouched and may be used only with the preserved legacy branch or another product.

### Requirement: Successful Captures Become Backup Commits

**Reason**: Montage no longer captures or commits machine backup snapshots.

**Migration**: Loadout library publication continues to create content-changing commits for selected portable items.

### Requirement: Backup History Is Selectable And Inspectable

**Reason**: Backup list/show, immutable backup selection, and historical restore are removed.

**Migration**: Loadout repository and item queries remain available for portable library content.

### Requirement: Backup Labels And Removal Are Explicit

**Reason**: Backup labels, retention, and history pruning are removed with vault history management.

**Migration**: Montage does not alter retained vault refs or history.

### Requirement: Vault Synchronization Preserves Local And Remote History

**Reason**: Active Montage no longer configures or synchronizes vault repositories.

**Migration**: Conservative synchronization remains available for configured loadout libraries only.

### Requirement: Vault Repository Remains Private By Guidance

**Reason**: Vault privacy and public-storage warnings are irrelevant when Montage has no vault repository type.

**Migration**: Existing private backup storage remains the user's responsibility outside active Montage; public loadout libraries continue to use credential-free remotes.
