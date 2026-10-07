## MODIFIED Requirements

### Requirement: Apply Is Previewed And Confirmed

The system SHALL show every install, tracking, sharing, conflict, refusal, and active-theme action a selected loadout can take and obtain confirmation before a live apply records desired state or mutates the machine.

#### Scenario: Apply preview is complete

- **WHEN** a valid repository loadout is selected
- **THEN** Montage lists packages, plugins, web apps, and the theme it would apply
- **AND** distinguishes resources it will install, protect as pre-existing, share with another loadout, defer, or refuse as conflicting
- **AND** states that dotfiles and arbitrary scripts are outside the operation

#### Scenario: Dry run does not install

- **WHEN** `mntg apply` is invoked with `--dry-run`
- **THEN** the same plan is displayed without installing, changing, or tracking anything

#### Scenario: Confirmed no-op apply is tracked

- **WHEN** every compatible resource in a confirmed loadout is already present
- **THEN** Montage records the loadout and its protected or shared claims
- **AND** does not reinstall those resources

### Requirement: Apply Reports Non-Healthy Outcomes Truthfully

The system SHALL distinguish healthy, pending, deferred, conflicting, uncertain, and failed loadout outcomes instead of reporting a fully successful apply when requested work remains unresolved.

#### Scenario: AUR work is declined

- **WHEN** the user confirms a loadout but declines its separately gated AUR work
- **THEN** Montage records the AUR claims as pending
- **AND** reports that the loadout is not yet healthy

#### Scenario: Integration installation fails

- **WHEN** a plugin, web app, theme, or package action fails after confirmation
- **THEN** Montage records the failed outcome
- **AND** the terminal and consumer protocol do not report unqualified success

### Requirement: Shared Code Is Pinned

The system SHALL install plugin or Git-theme code only at the commit recorded in the loadout unless the user explicitly permits unpinned entries.

#### Scenario: Pinned plugin is applied

- **WHEN** a loadout names a valid plugin remote and commit
- **THEN** Montage fetches the repository and checks out that commit detached

#### Scenario: Unpinned entry is refused by default

- **WHEN** a loadout names a plugin or cloneable theme without a commit
- **THEN** Montage skips it unless unpinned application was explicitly allowed

### Requirement: Explicit Share Selection Produces The Requested Subset

The system SHALL write exactly the non-empty set of valid current catalog resource identities selected by the user to a selected loadout item, with a user-supplied name and description, after reinspecting every selection immediately before the atomic repository update.

#### Scenario: Selected subset is exported

- **WHEN** the user selects a subset of currently shareable packages, plugins, web apps, and at most one theme for a repository loadout
- **THEN** that loadout's `profile.json` contains those selected resources and no other machine resources
- **AND** retains the fixed schema-version-1 portable loadout boundary

#### Scenario: Explicit selection becomes stale

- **WHEN** an explicitly selected resource is missing, changed incompatibly, unknown, or no longer shareable at export time
- **THEN** share refuses the update before changing the selected loadout or repository history
- **AND** identifies the resource and refusal reason

#### Scenario: Empty explicit selection is submitted

- **WHEN** the user attempts to update a loadout with an explicit selection containing no resources
- **THEN** share refuses to replace that loadout with an empty profile

#### Scenario: More than one theme is selected

- **WHEN** an explicit selection contains more than one theme
- **THEN** share refuses the update and leaves the selected loadout unchanged

### Requirement: Current Export Withdrawals Are Explicit

The system SHALL compare a selective update with the valid selected repository loadout and SHALL require identity-specific acknowledgement before dropping a previously exported resource that is now missing or unshareable.

#### Scenario: Previously exported resource is unavailable

- **WHEN** the selected loadout contains a resource that cannot be selected from the current machine
- **THEN** the resource remains visible as unavailable
- **AND** selective update does not remove it until the user acknowledges that exact withdrawal

#### Scenario: Available resource is deliberately deselected

- **WHEN** the user explicitly deselects a currently available resource from the selected loadout
- **THEN** share may omit it without an unavailable-resource acknowledgement
- **AND** the resulting profile and generated repository documentation reflect the new selection

#### Scenario: Acknowledged resource changes before export

- **WHEN** an acknowledgement names a resource that is no longer the same unavailable selected-loadout entry
- **THEN** share rejects the stale acknowledgement and preserves the selected loadout

### Requirement: Whole-Machine Share Remains Compatible

The system SHALL retain unfiltered capture into a selected loadout, the portable schema version, Git history behavior, and configured credential-free share URL semantics when no explicit resource selection is supplied. It SHALL NOT depend on a one-profile repository layout.

#### Scenario: Existing CLI invocation is used

- **WHEN** the user runs `mntg share` for an explicitly selected loadout without an explicit resource selection
- **THEN** Montage writes all currently representable resources to that loadout item
- **AND** existing name, description, and output-selection capabilities remain available through Montage syntax

### Requirement: Public Loadout URLs Carry No Credentials

The system SHALL refuse or sanitize credential-bearing URL input before it reaches share catalogs, profiles, generated instructions, configured repository locations, or applied-loadout state.

#### Scenario: Git remote contains credentials

- **WHEN** a shareable plugin or theme has an HTTPS remote containing user information
- **THEN** share evaluates and exports only the credential-free canonical remote
- **AND** catalog and generated output contain no credential-bearing form

#### Scenario: Web-app URL contains credentials

- **WHEN** a web-app candidate or incoming profile contains a URL with embedded credentials
- **THEN** Montage marks the candidate unavailable or refuses the profile entry
- **AND** does not silently export or install a different credential-free URL

#### Scenario: Profile repository origin contains credentials

- **WHEN** a loadout repository has a credential-bearing origin
- **THEN** generated share instructions and configured repository URLs use only a credential-free form
- **AND** do not reveal the supplied credential

## REMOVED Requirements

### Requirement: Short Links Are Resolved Locally

**Reason**: Ress-owned short links would retain a Ress service dependency and ambiguous product identity in Montage's native sharing workflow.

**Migration**: Import existing Ress links through the Ress v1 port adapter. Montage-native sharing uses canonical credential-free repository URLs plus an explicit stable loadout selector.
