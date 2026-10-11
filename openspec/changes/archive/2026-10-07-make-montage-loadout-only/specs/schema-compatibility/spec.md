# Spec Delta

## ADDED Requirements

### Requirement: Loadout Schemas Are Validated Before Use

The system SHALL accept a native loadout repository envelope, portable profile, applied registry, configured-repository document, or Ress loadout source version only when it is a plain supported integer and SHALL reject invalid or unsupported values before mutation.

#### Scenario: Hostile schema expression is supplied

- **WHEN** an artifact provides a schema version containing non-numeric shell or arithmetic syntax
- **THEN** Montage rejects it before evaluating that content or changing repository, registry, or machine state

#### Scenario: Unsupported future schema is supplied

- **WHEN** a well-formed schema version is newer than the supported version for its loadout artifact type
- **THEN** Montage stops with a compatibility error before share, apply, migration, or lifecycle mutation

### Requirement: Loadout Repository Envelope Remains Stable

The system SHALL continue to recognize schema-version-1 `montage.json` only as a loadout repository envelope with fixed `repositoryType: "loadouts"`.

#### Scenario: Existing native loadout library is opened

- **WHEN** its schema-version-1 envelope and contained profiles validate
- **THEN** Montage uses the library without rewriting it merely to remove the former repository-kind choice

#### Scenario: Vault envelope is opened

- **WHEN** `montage.json` identifies a vault repository or carries machine lineage
- **THEN** active Montage refuses it as an unsupported repository kind

### Requirement: Legacy Format Reading Is Migration Only

The system SHALL recognize supported Ress v1 control semantics only while inspecting or importing a portable Ress loadout profile and SHALL NOT interpret them as native Montage controls.

#### Scenario: Supported Ress profile is imported

- **WHEN** explicit Ress loadout migration receives a supported v1 profile
- **THEN** the migration boundary validates it and publishes a separate native library item

#### Scenario: Ress control appears in native runtime

- **WHEN** an ordinary Montage repository or apply operation encounters Ress-only repository, vault, or runtime controls
- **THEN** Montage refuses them rather than migrating or adopting them in place

## REMOVED Requirements

### Requirement: Vault Schema Version Is Validated Before Use

**Reason**: Native vault and backup schemas are removed; supported loadout artifacts are covered by the loadout-only validation requirements above.

**Migration**: Existing native loadout libraries retain schema version 1. Vault artifacts are not accepted by active Montage.

### Requirement: Current Manifest Name Is Canonical

**Reason**: `backup.json` and `.montage-bak` are Backup/Restore controls with no role in the Loadout product.

**Migration**: Portable loadouts continue to use `profile.json`; native libraries continue to use `montage.json`.

### Requirement: Defined Legacy Vault Artifacts Remain Readable

**Reason**: Ress vault import is removed and legacy support is narrowed to loadout-profile migration.

**Migration**: Import supported Ress `profile.json` artifacts through `ress-loadout-migration`; preserve vault artifacts outside active Montage.
