# schema-compatibility Specification

## Purpose

Defines the version and migration boundary that lets ress recognize supported vaults without evaluating hostile schema input or silently accepting incompatible formats.

## Requirements

### Requirement: Vault Schema Version Is Validated Before Use

The system SHALL accept a Montage repository envelope, backup snapshot, portable profile, or port source version only when it is a plain supported integer and SHALL reject invalid or unsupported values before mutation.

#### Scenario: Hostile schema expression is rejected

- **WHEN** an artifact provides a schema version containing non-numeric shell or arithmetic syntax
- **THEN** Montage rejects the artifact before evaluating that content or changing repository or machine state

#### Scenario: Unsupported future schema is rejected

- **WHEN** an artifact declares a well-formed schema version newer than the supported version for its artifact type
- **THEN** Montage stops with a compatibility error before import, backup, apply, or restore

### Requirement: Current Manifest Name Is Canonical

The system SHALL write the Montage repository envelope as `montage.json`, the current vault snapshot manifest as `backup.json`, and replacement files with a `.montage-bak` suffix. It SHALL NOT write `ress.json` as a Montage-native control file.

#### Scenario: New backup writes current manifest

- **WHEN** backup completes against a current Montage vault repository
- **THEN** the repository contains `montage.json` and `backup.json`
- **AND** does not write a Ress manifest as a native control

### Requirement: Defined Legacy Vault Artifacts Remain Readable

The system SHALL recognize supported Ress v1 manifests and backup suffixes only through the explicit Ress port adapter. It SHALL NOT migrate a Ress vault in place or interpret Ress controls as Montage-native repository controls.

#### Scenario: Legacy manifest is restored

- **WHEN** an explicit Ress import receives a supported legacy manifest name
- **THEN** the port adapter reads it under the supported Ress v1 rules in staging

#### Scenario: Legacy vault is backed up again

- **WHEN** the user confirms import of a supported Ress vault
- **THEN** Montage publishes a separate Montage-native repository
- **AND** leaves the Ress manifest names and source directory unchanged
