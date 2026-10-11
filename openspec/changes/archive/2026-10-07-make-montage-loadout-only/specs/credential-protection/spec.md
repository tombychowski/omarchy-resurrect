# Spec Delta

## REMOVED Requirements

### Requirement: Credentials Are Excluded From Plain Capture

**Reason**: Plain machine capture is removed and loadouts have no field for arbitrary files or secrets.

**Migration**: The constrained profile boundary remains in `loadout-sharing`; use a separate secrets product or secure channel for credentials.

### Requirement: Vault Is Scanned Before Commit

**Reason**: Vault content, backup commits, and explicit vault scanning are removed.

**Migration**: Loadout validators continue to reject credential-bearing URLs and unsupported fields before library publication or apply.

### Requirement: URL Credentials Are Ephemeral

**Reason**: The surviving rule is no longer a vault or secret-transport concern.

**Migration**: Credential-free remote, profile, catalog, instruction, and applied-state behavior remains under `loadout-sharing` and `loadout-repositories`.

### Requirement: Secret Transport Is Explicit And Encrypted

**Reason**: Encrypted secret backup and transport are outside the Loadout product.

**Migration**: Montage neither stores nor restores secrets. Existing encrypted vault artifacts remain user-owned outside active Montage.

### Requirement: Decryption Preserves Private Permissions

**Reason**: Montage no longer decrypts or restores backup secret bundles.

**Migration**: Users must use an independent secrets-management or backup workflow.
