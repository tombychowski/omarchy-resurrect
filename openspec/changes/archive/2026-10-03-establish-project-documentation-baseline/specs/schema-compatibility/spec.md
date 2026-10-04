# Spec Delta

## Purpose

Defines the version and migration boundary that lets ress recognize supported vaults without evaluating hostile schema input or silently accepting incompatible formats.

## ADDED Requirements

### Requirement: Vault Schema Version Is Validated Before Use
The system SHALL accept a vault schema version only when it is a plain supported integer and SHALL reject invalid or unsupported values before mutation.

#### Scenario: Hostile schema expression is rejected
- **WHEN** a fetched vault provides a schema version containing non-numeric shell or arithmetic syntax
- **THEN** ress rejects the vault before evaluating that content or changing machine state

#### Scenario: Unsupported future schema is rejected
- **WHEN** a vault declares a well-formed schema version newer than the supported version
- **THEN** ress stops with a compatibility error before restore

### Requirement: Current Manifest Name Is Canonical
The system SHALL write the current vault manifest as `ress.json`.

#### Scenario: New backup writes current manifest
- **WHEN** backup completes against a current vault
- **THEN** the vault contains `ress.json`
- **AND** does not write the legacy manifest name

### Requirement: Defined Legacy Vault Artifacts Remain Readable
The system SHALL recognize the supported legacy manifest and backup suffixes and SHALL migrate the legacy manifest name during a subsequent backup.

#### Scenario: Legacy manifest is restored
- **WHEN** a supported vault contains the legacy manifest name
- **THEN** restore reads it under the supported schema rules

#### Scenario: Legacy vault is backed up again
- **WHEN** backup runs against a vault using the legacy manifest name
- **THEN** ress writes the canonical manifest
- **AND** removes the obsolete manifest name from the new snapshot
