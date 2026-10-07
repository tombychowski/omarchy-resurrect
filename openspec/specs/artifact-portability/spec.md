# artifact-portability Specification

## Purpose

Define a reusable and safety-preserving interchange boundary so Montage can add explicitly versioned foreign formats without coupling its native repositories to any predecessor.

## Requirements

### Requirement: Port Formats Are Explicitly Selected

The system SHALL dispatch port operations only to an explicitly supported, versioned format adapter and SHALL identify that format in every machine-readable report.

#### Scenario: Supported format is selected

- **WHEN** a user requests a port operation for a supported format
- **THEN** Montage SHALL dispatch to that format's bounded adapter
- **AND** SHALL report the adapter's stable format identifier

#### Scenario: Unsupported format is selected

- **WHEN** a user requests a port operation for an unsupported format identifier
- **THEN** Montage SHALL refuse before reading a source or changing a destination

### Requirement: Port Lifecycle Safety Is Format Neutral

The shared port engine SHALL enforce source preservation, destination isolation, dry-run, history selection, exact native selection, exact loss consent, confirmation, repository transactions, staging, validation sequencing, commit creation, atomic publication, and result output independently of foreign-format parsing rules. A format adapter SHALL be limited to format description, detection, semantic facts, decision/loss discovery, translation, and staged foreign validation callbacks.

#### Scenario: Adapter publishes a conversion

- **WHEN** a format adapter produces a candidate conversion
- **THEN** Montage SHALL validate it before publishing to an absent or explicitly empty separate destination
- **AND** SHALL leave the source unchanged

#### Scenario: Adapter reports non-waivable loss

- **WHEN** conversion cannot preserve a required credential, containment, consent, private-key, or cleanup-authority guarantee
- **THEN** Montage SHALL refuse even when the user accepts representational loss

#### Scenario: Adapter requests publication

- **WHEN** a validated adapter translation is ready to become persistent
- **THEN** the shared engine SHALL perform confirmation, native validation, commit creation, and publication
- **AND** the adapter SHALL NOT traverse Git history, select native repositories, acquire native transaction locks, create staging workspaces, publish paths, or emit consumer results

#### Scenario: Historical source revision is read

- **WHEN** a port operation selects a Git revision from a foreign source
- **THEN** the shared engine SHALL reconstruct it through the envelope-neutral contained Git-object reader
- **AND** the adapter SHALL validate only the isolated tree passed to its callback

#### Scenario: Recognized control is not a complete import source

- **WHEN** inspection recognizes a foreign control file but its containing artifact is not sufficient for the requested import operation
- **THEN** planning SHALL report the source as incompatible for that operation
- **AND** SHALL NOT advertise executable destination mutations

### Requirement: Port Reports Use One Extensible Envelope

The system SHALL emit `montage-port-report` schema-version-1 JSON for inspection, planning, refusal, and publication results, with a stable format identifier and operation-independent decision fields.

#### Scenario: Consumer reads a port preview

- **WHEN** a consumer requests JSON inspection or planning for any supported format
- **THEN** it receives one `montage-port-report` object containing `format`, operation, compatibility, source, destination, warnings, losses, mutations, selected revisions, and publication state as applicable

#### Scenario: JSON operation requires a format decision

- **WHEN** a JSON import or export request is refused because a required format-specific decision is missing
- **THEN** Montage SHALL emit one incompatible `montage-port-report` naming the decision reason
- **AND** SHALL NOT replace that report with prose-only output

### Requirement: New Formats Remain Isolated

The system SHALL require each foreign format to define its own version boundary, detection, validation, translation, fixtures, and compatibility evidence without changing native Montage readers.

#### Scenario: A future format is added

- **WHEN** Montage adds support for another foreign artifact format
- **THEN** the new adapter SHALL use the shared port lifecycle and report contract
- **AND** SHALL implement only literal callbacks registered by the shared adapter dispatch
- **AND** native vault and loadout readers SHALL remain free of that foreign format's parsing rules
