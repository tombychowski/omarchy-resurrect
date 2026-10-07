# Spec Delta

## Purpose

Defines the independently installable Montage application identity, its public command, and the local namespaces that allow Montage and Ress to coexist without owning one another's runtime state.

## ADDED Requirements

### Requirement: Montage Has A Distinct Omarchy Plugin Identity
The system SHALL publish Montage under plugin id `tombychowski.montage`, use that id for its installed directory and IPC target, and avoid claiming the existing Ress plugin id.

#### Scenario: Both plugins are installed
- **WHEN** a machine installs Montage while `tsouth89.resurrect` is present
- **THEN** Omarchy discovers both plugins under distinct ids
- **AND** either plugin can be enabled, updated, disabled, or removed without targeting the other

#### Scenario: Montage receives an IPC command
- **WHEN** a caller addresses the Montage IPC target
- **THEN** only the Montage panel or service handles the command

### Requirement: Montage Uses The Mntg Command
The system SHALL expose `mntg` as Montage's public CLI and SHALL NOT install `montage` or `ress` as a Montage PATH command.

#### Scenario: User links the CLI
- **WHEN** the user runs `mntg link`
- **THEN** Montage creates or updates its owned `~/.local/bin/mntg` link
- **AND** leaves the existing `ress` and ImageMagick `montage` commands unchanged

#### Scenario: Link target belongs to another program
- **WHEN** `~/.local/bin/mntg` exists and is not an owned link to the active Montage installation
- **THEN** Montage refuses to replace it
- **AND** explains how to resolve the collision explicitly

### Requirement: Montage Owns Separate Local Namespaces
The system SHALL keep Montage configuration, operational state, registry data, locks, and default repositories below Montage-specific XDG paths and SHALL NOT use Ress paths during ordinary operation.

#### Scenario: Montage starts beside Ress
- **WHEN** both applications use their default configuration
- **THEN** Montage reads and writes only Montage-owned config, state, and data roots
- **AND** Ress files do not determine Montage's live settings, scheduler, running state, or cleanup authority

#### Scenario: Ress is removed
- **WHEN** a user removes the Ress plugin after installing Montage
- **THEN** Montage's plugin, command link, configuration, state, repositories, and panel remain usable

### Requirement: User-Facing Identity Is Montage
The system SHALL identify the active product as Montage in human output, generated native documentation, panel language, installation instructions, and release metadata.

#### Scenario: User requests command help
- **WHEN** the user runs `mntg --help` or `mntg status`
- **THEN** the output identifies Montage and uses `mntg` in suggested commands

#### Scenario: Historical evidence is displayed
- **WHEN** documentation presents a historical Ress changelog entry or archived change
- **THEN** it preserves the historical name rather than rewriting past evidence as Montage behavior
