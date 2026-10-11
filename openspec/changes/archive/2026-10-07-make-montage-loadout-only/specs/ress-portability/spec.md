# Spec Delta

## REMOVED Requirements

### Requirement: Ress Compatibility Is A Versioned Port Boundary

**Reason**: The combined vault-and-loadout import/export boundary is replaced by import-only Ress v1 loadout migration.

**Migration**: Use `ress-loadout-migration` to inspect and import supported portable profiles.

### Requirement: Porting Never Shares Live Product State

**Reason**: The broad port capability is retired; its surviving source-isolation and no-authority guarantees move to `ress-loadout-migration`.

**Migration**: Ress runtime state remains separate and is never adopted during loadout migration.

### Requirement: Current Snapshot Import Is The Default

**Reason**: Snapshot and vault import are removed; only one explicitly selected loadout profile may be migrated.

**Migration**: Select a Montage library and stable loadout id, then import the supported Ress profile.

### Requirement: History Translation Is Explicit And Optional

**Reason**: Ress vault history translation and compatible-subset publication are outside the Loadout product.

**Migration**: Preserve Ress history outside Montage. Only the selected current portable profile may cross the migration boundary.

### Requirement: Ress Export Produces A Disposable Compatibility Copy

**Reason**: Montage-to-Ress loadout export and backup export are removed; Ress compatibility is migration into Montage only.

**Migration**: Retain any existing exported copies independently. Active Montage provides no reverse conversion.

### Requirement: Lossy Conversion Requires Specific Consent

**Reason**: The generic bidirectional conversion rule is retired; applicable loadout-import loss and non-waivable safety rules move to `ress-loadout-migration`.

**Migration**: Review and accept only the exact representational decisions reported by Ress loadout migration.

### Requirement: Port Operations Are Previewable And Machine Readable

**Reason**: General port inspection, planning, import, and export no longer exist as one operation family.

**Migration**: Use the focused human or JSON Ress loadout inspection and import preview.

### Requirement: Self-Plugin Entries Are Never Silently Reassigned

**Reason**: Bidirectional self-plugin conversion is retired; the surviving Ress-to-Montage decision is owned by `ress-loadout-migration`.

**Migration**: Ress plugin entries are reported during import and are never silently mapped to Montage.
