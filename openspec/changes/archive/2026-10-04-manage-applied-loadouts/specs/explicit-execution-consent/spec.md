# Spec Delta

## MODIFIED Requirements

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

