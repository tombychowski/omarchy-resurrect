# Spec Delta

## ADDED Requirements

### Requirement: External Operation State Tracks The Lock Owner
The panel-visible running state SHALL remain present for the lifetime of the live CLI process that owns the primary operation lock and SHALL NOT be cleared by unrelated CLI processes.

#### Scenario: Read command exits during a live operation
- **WHEN** a backup, restore, or loadout mutation owns the operation lock and an unrelated status, query, help, or version command exits
- **THEN** the panel continues to observe the external operation as running
- **AND** only the lock-owning operation removes its marker when it finishes

#### Scenario: Dry run owns no visible marker
- **WHEN** a dry-run operation acquires the primary lock for a coherent plan
- **THEN** it does not create or remove the panel-visible running marker

### Requirement: Panel Setting Writes Remain Serialized
CLI configuration updates initiated by the panel or terminal SHALL complete only while holding the dedicated configuration lock.

#### Scenario: Configuration lock times out
- **WHEN** a settings update cannot acquire the configuration lock within the supported timeout
- **THEN** the update fails with a clear error
- **AND** does not write configuration from an unlocked or stale read

#### Scenario: Concurrent setting writes serialize
- **WHEN** two setting updates are issued close together
- **THEN** each successful writer rereads configuration while holding the lock
- **AND** one successful update does not discard the other
