# Spec Delta

## Purpose

Defines how ress previews and replays a trusted machine vault safely across interruptions, category selections, and deferred consent decisions.

## ADDED Requirements

### Requirement: Restore Preview Before Mutation
The system SHALL describe the vault contents, planned category actions, and executable or persistent content before requesting confirmation for a live restore.

#### Scenario: Live restore presents a preview
- **WHEN** a user starts a restore from a valid vault
- **THEN** ress lists the work it plans to perform before modifying the machine
- **AND** requests confirmation unless an applicable explicit option already supplies it

### Requirement: Category Selection
The system SHALL allow restore categories to be included or excluded explicitly and SHALL reject unknown category names.

#### Scenario: Restore only selected categories
- **WHEN** a user passes `--only` with valid categories
- **THEN** restore performs only those categories

#### Scenario: Unknown category is rejected
- **WHEN** a user supplies a category name outside the supported set
- **THEN** restore exits with an error before changing machine state

### Requirement: Resumable Progress
The system SHALL persist completion progress for one vault snapshot so an interrupted restore can continue without repeating completed categories.

#### Scenario: Interrupted restore resumes
- **WHEN** a restore stops after one or more categories complete and is rerun against the same snapshot
- **THEN** completed categories are skipped
- **AND** remaining categories are offered or executed

#### Scenario: Changed snapshot does not reuse stale progress
- **WHEN** the selected vault snapshot differs from the snapshot associated with saved restore progress
- **THEN** ress does not treat the new snapshot's categories as already complete

### Requirement: Dry-Run Fidelity
The system SHALL make a dry run describe what each selected category would do without mutating the vault or machine.

#### Scenario: Dry run changes nothing
- **WHEN** restore is invoked with `--dry-run`
- **THEN** it reports planned category actions
- **AND** does not install packages, write configuration, enable services, change themes, or update restore progress

