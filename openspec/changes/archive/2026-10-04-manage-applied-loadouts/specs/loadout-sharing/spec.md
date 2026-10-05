# Spec Delta

## MODIFIED Requirements

### Requirement: Apply Is Previewed And Confirmed
The system SHALL show every install, tracking, sharing, conflict, refusal, and active-theme action a loadout can take and obtain confirmation before a live apply records desired state or mutates the machine.

#### Scenario: Apply preview is complete
- **WHEN** a valid loadout is selected
- **THEN** ress lists packages, plugins, web apps, and the theme it would apply
- **AND** distinguishes resources it will install, protect as pre-existing, share with another loadout, defer, or refuse as conflicting
- **AND** states that dotfiles and arbitrary scripts are outside the operation

#### Scenario: Dry run does not install
- **WHEN** loadout apply is invoked with `--dry-run`
- **THEN** the same plan is displayed without installing, changing, or tracking anything

#### Scenario: Confirmed no-op apply is tracked
- **WHEN** every compatible resource in a confirmed loadout is already present
- **THEN** ress records the loadout and its protected or shared claims
- **AND** does not reinstall those resources

## ADDED Requirements

### Requirement: Apply Reports Non-Healthy Outcomes Truthfully
The system SHALL distinguish healthy, pending, deferred, conflicting, uncertain, and failed loadout outcomes instead of reporting a fully successful apply when requested work remains unresolved.

#### Scenario: AUR work is declined
- **WHEN** the user confirms a loadout but declines its separately gated AUR work
- **THEN** ress records the AUR claims as pending
- **AND** reports that the loadout is not yet healthy

#### Scenario: Integration installation fails
- **WHEN** a plugin, web app, theme, or package action fails after confirmation
- **THEN** ress records the failed outcome
- **AND** the terminal and consumer protocol do not report unqualified success
