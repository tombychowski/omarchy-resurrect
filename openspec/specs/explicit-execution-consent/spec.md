# explicit-execution-consent Specification

## Purpose

Defines the independent consent gates for actions that execute fetched build instructions or arrange for code to run in future sessions.

## Requirements

### Requirement: AUR Builds Require Separate Consent
The system SHALL require an explicit AUR decision before building packages from PKGBUILDs during restore, loadout apply, or loadout repair, independently of general operation confirmation.

#### Scenario: General yes does not authorize AUR
- **WHEN** restore, loadout apply, or loadout repair is run with `--yes` but without an AUR choice
- **THEN** ress does not infer permission to build AUR packages

#### Scenario: Review mode preserves package review
- **WHEN** the user chooses AUR review mode
- **THEN** ress invokes the AUR helper without automatically answering package review questions

#### Scenario: Denied package is removed before consent
- **WHEN** an AUR package is present in the configured deny list
- **THEN** ress excludes it before presenting or executing the build decision

#### Scenario: Declined loadout repair remains pending
- **WHEN** the user declines an AUR build offered during loadout repair
- **THEN** ress leaves the affected claim pending
- **AND** a later repair can offer it again

### Requirement: Persistent Services Require Separate Consent
The system SHALL require an explicit decision before enabling captured systemd user services and SHALL show what each candidate service executes.

#### Scenario: General yes does not enable services
- **WHEN** restore is run with `--yes` but without a service-enablement choice
- **THEN** ress does not infer permission to enable user services

#### Scenario: Service prompt is informed
- **WHEN** pending captured services are offered for enablement
- **THEN** the prompt identifies the services and their executable commands before asking

### Requirement: Declined Gated Work Remains Pending
The system SHALL distinguish declined gated work from completed or failed work.

#### Scenario: Declined AUR packages are offered later
- **WHEN** the user declines the AUR build step
- **THEN** restore does not mark the AUR work complete
- **AND** a later restore can offer it again

#### Scenario: Deferred services can be enabled separately
- **WHEN** captured services were not enabled during restore
- **THEN** the user can inspect and enable them later through the dedicated command

### Requirement: Autostart Capture Is Explicit
The system SHALL exclude autostart entries by default and SHALL capture them only after the user enables the autostart setting.

#### Scenario: Default backup excludes autostart
- **WHEN** autostart capture has not been enabled
- **THEN** backup does not place autostart launchers in the vault
