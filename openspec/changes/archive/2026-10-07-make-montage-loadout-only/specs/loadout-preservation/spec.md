# Spec Delta

## Purpose

Defines the preservation and cleanup-authority guarantees that keep Loadout application and removal additive, inspectable, and narrowly scoped.

## ADDED Requirements

### Requirement: Loadout Application Is Additive

The system SHALL install or create only missing requested resources and SHALL NOT remove machine resources merely because they are absent from a loadout.

#### Scenario: Extra package is not requested

- **WHEN** the current machine has a package that is absent from the selected loadout
- **THEN** loadout apply leaves that package installed

#### Scenario: Requested package is already installed

- **WHEN** a requested package is already present
- **THEN** loadout apply protects or shares the existing resource without reinstalling it solely to satisfy the claim

### Requirement: Loadout Removal Uses Recorded Authority Only

The system SHALL treat confirmed removal as authority only to release the selected loadout's claims and remove an unchanged resource that Montage verifiably introduced for the final claim.

#### Scenario: Unrelated resource remains

- **WHEN** a user removes a tracked loadout
- **THEN** resources absent from that loadout's validated claims remain untouched

#### Scenario: Shared resource remains

- **WHEN** another tracked loadout has a compatible claim on the resource
- **THEN** Montage releases only the removed loadout's claim
- **AND** leaves the resource present

#### Scenario: Pre-existing resource remains

- **WHEN** the removed loadout is the final claimant of a resource that existed before Montage tracking
- **THEN** Montage releases the claim and leaves the resource present

### Requirement: Changed Or Unverifiable Resources Are Preserved

The system SHALL NOT automatically delete a claimed resource whose current identity or contents no longer match recorded safe-removal evidence or cannot be verified safely.

#### Scenario: Introduced plugin has local changes

- **WHEN** a plugin introduced by Montage is modified before its final claim is removed
- **THEN** Montage preserves it until the user makes the separately previewed resource decision

#### Scenario: Resource evidence is unavailable

- **WHEN** Montage cannot safely determine whether an exclusively claimed resource still matches
- **THEN** removal reports the resource as unverifiable or decision-required
- **AND** does not delete it automatically

### Requirement: Cleanup Does Not Infer Unrecorded Ownership

The system SHALL NOT infer authority over dependencies, configuration, caches, application data, or other resources merely from removing a tracked loadout resource.

#### Scenario: Package dependencies become orphaned

- **WHEN** removal of a Montage-introduced package leaves dependencies no longer required by installed packages
- **THEN** Montage does not automatically remove those dependencies

#### Scenario: Application data remains

- **WHEN** a package, plugin, web app, or theme is removed
- **THEN** Montage does not infer deletion of unrelated user configuration or data
