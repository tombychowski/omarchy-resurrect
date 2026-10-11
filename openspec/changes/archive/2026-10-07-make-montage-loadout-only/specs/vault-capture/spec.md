# Spec Delta

## REMOVED Requirements

### Requirement: Category-Based Machine Capture

**Reason**: Montage no longer captures machine state or writes backup snapshots.

**Migration**: Use Loadout composition to select only supported packages, pinned plugins, reconstructible web apps, and a theme.

### Requirement: Curated Configuration Boundary

**Reason**: Dotfile and arbitrary configuration capture are outside the constrained Loadout product.

**Migration**: Existing vault content remains user-owned; active Montage neither reads nor updates it.

### Requirement: Portable Reconstruction Evidence

**Reason**: Backup omission and reconstructibility reporting are removed with machine capture.

**Migration**: The Share catalog continues to report unavailable Loadout candidates and their refusal reasons.

### Requirement: Montage Operational Artifacts Are Excluded From Capture

**Reason**: There is no machine capture path from which Montage operational artifacts must be excluded.

**Migration**: Loadout profiles remain constrained by schema and cannot contain Montage config, state, registries, locks, credentials, or arbitrary files.
