# loadout-reconciliation Specification

## Purpose

Defines how ress detects and repairs drift from tracked loadout desired state and safely removes a loadout without deleting shared, protected, or externally changed resources.

## Requirements

### Requirement: Loadout Health Reflects Current Resources
The system SHALL compare each tracked resource with the evidence its resource kind can safely verify and SHALL classify it as present, missing, modified, conflicting, protected, or unverifiable.

#### Scenario: Resource was removed outside ress
- **WHEN** a resource claimed by an applied loadout is no longer present
- **THEN** loadout checking reports the resource as missing
- **AND** the loadout is not reported as healthy

#### Scenario: Pinned code changed outside ress
- **WHEN** a claimed plugin or installed theme no longer matches its expected remote or pinned commit
- **THEN** loadout checking reports it as modified or conflicting rather than present

#### Scenario: Package version changes
- **WHEN** a named package remains installed at a newer or older version
- **THEN** ress treats the name-based package resource as present unless the loadout format carries a version constraint

### Requirement: Repair Is Explicit And Previewed
The system SHALL repair missing or safely restorable tracked resources only through an explicit operation that previews its complete actions and supports a no-mutation dry run.

#### Scenario: Check does not repair automatically
- **WHEN** a status, list, or check operation finds a missing resource
- **THEN** ress reports the drift without reinstalling it

#### Scenario: Repair reinstalls a missing resource
- **WHEN** the user confirms repair of a missing resource
- **THEN** ress applies the same validation, pinning, and resource-specific safeguards used for loadout application
- **AND** records the repair outcome

#### Scenario: Repair preview changes nothing
- **WHEN** repair is invoked with `--dry-run`
- **THEN** ress reports the actions and consent boundaries without changing machine or registry state

### Requirement: Loadout Removal Is Previewed And Confirmed
The system SHALL expose loadout withdrawal as `ress loadout remove`, show every resource action and retention reason before mutation, and require confirmation unless an applicable explicit option supplies it.

#### Scenario: Removal preview is complete
- **WHEN** a tracked loadout is selected for removal
- **THEN** ress identifies resources to delete, claims to release, resources to retain, conflicts needing a decision, and any active-theme transition

#### Scenario: Removal dry run changes nothing
- **WHEN** loadout removal is invoked with `--dry-run`
- **THEN** ress produces the same plan without deleting resources or changing registry state

### Requirement: Removal Respects Claims And Provenance
The system SHALL remove a resource automatically only when ress introduced it, the selected loadout owns its final claim, the resource is unchanged, and no safety protection forbids removal.

#### Scenario: Shared resource remains
- **WHEN** a removed loadout shares a compatible resource with another tracked loadout
- **THEN** ress releases only the removed loadout's claim
- **AND** leaves the resource present

#### Scenario: Pre-existing resource remains
- **WHEN** the removed loadout is the final claimant of a resource that pre-existed tracking
- **THEN** ress releases the claim and leaves the resource present

#### Scenario: Exclusive ress resource is removed
- **WHEN** the removed loadout is the final claimant of an unchanged resource introduced by ress
- **THEN** ress removes that resource through its supported resource-specific mechanism

#### Scenario: Resource is already absent
- **WHEN** an exclusively claimed resource is already missing at removal time
- **THEN** ress reports it as already removed and releases the claim without recreating it

### Requirement: Modified Resources Require A Decision
The system SHALL preserve an exclusively claimed resource that no longer matches the evidence recorded after ress created it until the user explicitly chooses to retain or remove the changed resource.

#### Scenario: Modified plugin blocks automatic cleanup
- **WHEN** a plugin introduced by ress has local changes or a different commit before its final claim is removed
- **THEN** ress does not delete it by default
- **AND** keeps the loadout in removal-pending state with the available decisions reported

#### Scenario: User keeps modified resource
- **WHEN** the user explicitly chooses to retain a modified resource while resolving removal
- **THEN** ress relinquishes its claim and cleanup authority
- **AND** leaves the resource as unmanaged machine state

### Requirement: Removal Is Resumable
The system SHALL record each resolved claim during removal and SHALL remove the loadout from active tracking only after every claim and effect has reached a terminal outcome.

#### Scenario: Removal is interrupted
- **WHEN** removal stops after some resources or claims are resolved
- **THEN** the loadout remains removal-pending
- **AND** rerunning removal skips completed cleanup and continues unresolved work

#### Scenario: Removal completes
- **WHEN** every claim has been released and every required cleanup or retention decision has succeeded
- **THEN** ress removes the loadout from the active registry

### Requirement: Theme Selection Has Deterministic Precedence
The system SHALL track installed themes separately from active-theme intent and SHALL give the most recently successfully applied remaining loadout precedence unless an external theme choice is being preserved.

#### Scenario: Current loadout theme is removed
- **WHEN** the removed loadout supplies the effective active theme and another tracked loadout requests a usable theme
- **THEN** ress activates the most recently applied remaining request before deleting any removable theme files

#### Scenario: Last managed theme is removed
- **WHEN** the final effective theme request is removed and the recorded baseline theme remains available
- **THEN** ress restores the baseline theme before deleting any removable theme files

#### Scenario: User selected another theme externally
- **WHEN** current machine state shows a theme selection made outside the managed precedence state
- **THEN** ress preserves that selection by default
- **AND** reports the managed theme divergence rather than overriding it during unrelated cleanup

### Requirement: Package Cleanup Is Narrow And Dependency-Safe
The system SHALL remove only explicitly tracked package targets, SHALL respect package-manager dependency refusal, and SHALL NOT cascade, ignore dependencies, or automatically remove orphaned dependencies.

#### Scenario: Package is required elsewhere
- **WHEN** the package manager refuses removal because another installed package requires the target
- **THEN** ress retains the resource claim as removal-pending and reports the dependency

#### Scenario: Cleanup exposes orphaned dependencies
- **WHEN** removal leaves packages that the package manager reports as unneeded dependencies
- **THEN** ress may report them as follow-up information
- **AND** does not remove them as part of loadout cleanup

#### Scenario: Critical package is protected
- **WHEN** an owned package is required for ress, package management, or the supported Omarchy runtime
- **THEN** ress refuses automatic removal and reports the protection
