# Spec Delta

## ADDED Requirements

### Requirement: Share Catalog Reports Current Candidates Truthfully
The system SHALL expose current-machine loadout candidates with stable identities, resource kinds, present shareability, and a reason for each detected candidate that cannot be represented safely in a loadout.

#### Scenario: Catalog distinguishes shareable and unavailable resources
- **WHEN** the machine contains supported resources and detected resources that lack a safe loadout representation
- **THEN** the share catalog lists the supported resources as selectable
- **AND** lists each relevant unavailable candidate with a refusal reason rather than silently treating it as shareable

#### Scenario: Catalog preserves the loadout boundary
- **WHEN** the share catalog is requested
- **THEN** it describes only packages, plugins, reconstructible web apps, and themes
- **AND** does not expose dotfile contents, secrets, arbitrary files, commands, or credential-bearing remotes

### Requirement: Explicit Share Selection Produces The Requested Subset
The system SHALL export exactly the non-empty set of valid current catalog resource identities explicitly selected by the user, with a user-supplied name and description, after reinspecting every selection immediately before writing the profile.

#### Scenario: Selected subset is exported
- **WHEN** the user selects a subset of currently shareable packages, plugins, web apps, and at most one theme
- **THEN** the generated profile contains those selected resources and no other machine resources
- **AND** retains the fixed schema-version-1 loadout boundary

#### Scenario: Explicit selection becomes stale
- **WHEN** an explicitly selected resource is missing, changed incompatibly, unknown, or no longer shareable at export time
- **THEN** share refuses the export before changing the existing profile repository
- **AND** identifies the resource and refusal reason

#### Scenario: Empty explicit selection is submitted
- **WHEN** the user attempts to export an explicit selection containing no resources
- **THEN** share refuses to replace the current profile with an empty loadout

#### Scenario: More than one theme is selected
- **WHEN** an explicit selection contains more than one theme
- **THEN** share refuses the export and leaves the current profile unchanged

### Requirement: Current Export Withdrawals Are Explicit
The system SHALL compare a selective export with the valid current profile and SHALL require identity-specific acknowledgement before dropping a previously exported resource that is now missing or unshareable.

#### Scenario: Previously exported resource is unavailable
- **WHEN** a valid current profile contains a resource that cannot be selected from the current machine
- **THEN** the resource remains visible as unavailable
- **AND** selective export does not remove it until the user acknowledges that exact withdrawal

#### Scenario: Available resource is deliberately deselected
- **WHEN** the user explicitly deselects a currently available resource from the current profile
- **THEN** share may omit it without an unavailable-resource acknowledgement
- **AND** the resulting profile and generated README reflect the new selection

#### Scenario: Acknowledged resource changes before export
- **WHEN** an acknowledgement names a resource that is no longer the same unavailable current-profile entry
- **THEN** share rejects the stale acknowledgement and preserves the existing profile

### Requirement: Whole-Machine Share Remains Compatible
The system SHALL retain the existing unfiltered share workflow, schema version, default profile repository, Git history behavior, and configured share URL semantics when no explicit selection is supplied.

#### Scenario: Existing CLI invocation is used
- **WHEN** the user runs `ress share` without an explicit resource selection
- **THEN** ress exports all currently representable resources using the existing default profile repository
- **AND** existing `--name`, `--description`, and `--out` behavior remains supported

