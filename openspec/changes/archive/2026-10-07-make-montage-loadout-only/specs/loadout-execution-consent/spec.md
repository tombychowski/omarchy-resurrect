# Spec Delta

## Purpose

Defines the independent consent and truthful outcome rules for AUR build instructions executed during Loadout application and reconciliation.

## ADDED Requirements

### Requirement: AUR Builds Require Separate Consent

The system SHALL require an explicit AUR decision before building packages from PKGBUILDs during loadout apply or repair, independently of general operation confirmation.

#### Scenario: General confirmation does not authorize AUR

- **WHEN** apply or repair is run with `--yes` but without an AUR choice
- **THEN** Montage does not infer permission to build AUR packages

#### Scenario: Review mode preserves package review

- **WHEN** the user selects AUR review mode
- **THEN** Montage invokes the AUR helper without automatically answering package review questions

#### Scenario: Denied package is removed before consent

- **WHEN** an AUR package is present in the configured deny list
- **THEN** Montage excludes it before presenting or executing the build decision

### Requirement: Declined AUR Work Remains Pending

The system SHALL record declined AUR work as unresolved desired state rather than as completed or failed work that cannot be resumed.

#### Scenario: Apply AUR work is declined

- **WHEN** the user confirms a loadout but declines its AUR build step
- **THEN** Montage records the affected claims as pending or deferred
- **AND** does not report the loadout as healthy

#### Scenario: Repair is attempted later

- **WHEN** a later repair finds a pending AUR claim
- **THEN** Montage offers the AUR decision again under the same independent consent gate

### Requirement: AUR Outcomes Are Machine Readable

The system SHALL expose deferred, denied, failed, and completed AUR outcomes through the same loadout registry and consumer protocols used for other resource actions.

#### Scenario: Consumer observes deferred AUR work

- **WHEN** AUR work remains unresolved after apply or repair
- **THEN** JSON or porcelain output reports a qualified non-success outcome and the affected resource state
