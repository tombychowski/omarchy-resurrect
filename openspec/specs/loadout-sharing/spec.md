# loadout-sharing Specification

## Purpose

Defines a constrained setup-sharing format that can install named software and integrations without carrying user files or executable payloads.

## Requirements

### Requirement: Loadout Contains Only Supported Setup Actions
The system SHALL limit a loadout to packages, pinned plugins, reconstructible web apps, and a theme selection.

#### Scenario: Share excludes home content
- **WHEN** a user exports a loadout from a vault
- **THEN** the loadout contains no dotfiles, secret bundle, arbitrary file content, or command field

#### Scenario: Unrepresentable launcher is omitted
- **WHEN** a captured web app requires launcher behavior the loadout format cannot represent
- **THEN** share omits it and reports the omission

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

### Requirement: Shared Code Is Pinned
The system SHALL install plugin or Git-theme code only at the commit recorded in the loadout unless the user explicitly permits unpinned entries.

#### Scenario: Pinned plugin is applied
- **WHEN** a loadout names a valid plugin remote and commit
- **THEN** ress fetches the repository and checks out that commit detached

#### Scenario: Unpinned entry is refused by default
- **WHEN** a loadout names a plugin or cloneable theme without a commit
- **THEN** ress skips it unless unpinned application was explicitly allowed

### Requirement: Short Links Are Resolved Locally
The system SHALL expand supported ress short links to their canonical repository URLs before making a network request.

#### Scenario: GitHub short link is applied
- **WHEN** the user provides a supported `ress.sh` GitHub link
- **THEN** ress derives the GitHub repository URL locally
- **AND** fetches the repository rather than requesting the shortener

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

### Requirement: Public Loadout URLs Carry No Credentials
The system SHALL refuse or sanitize credential-bearing URL input before it reaches share catalogs, profiles, generated instructions, configured share locations, or applied-loadout state.

#### Scenario: Git remote contains credentials
- **WHEN** a shareable plugin or theme has an HTTPS remote containing user information
- **THEN** share evaluates and exports only the credential-free canonical remote
- **AND** catalog and generated output contain no credential-bearing form

#### Scenario: Web-app URL contains credentials
- **WHEN** a web-app candidate or incoming profile contains a URL with embedded credentials
- **THEN** ress marks the candidate unavailable or refuses the profile entry
- **AND** does not silently export or install a different credential-free URL

#### Scenario: Profile repository origin contains credentials
- **WHEN** the output profile repository has a credential-bearing origin
- **THEN** generated share instructions and configured profile URL use only a credential-free form
- **AND** do not reveal the supplied credential
