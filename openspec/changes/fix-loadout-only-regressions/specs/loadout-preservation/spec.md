## ADDED Requirements

### Requirement: Failed Package Observation Grants No Cleanup Authority
The system SHALL distinguish unsuccessful package inventory from a successful observation of absence and SHALL NOT install or acquire deletion authority for a package whose prior presence is unavailable.

#### Scenario: Package inventory fails
- **WHEN** package inventory fails or returns partial output with failure status
- **THEN** requested package observation is unverifiable
- **AND** no package is installed or assigned newly inferred removal authority

### Requirement: Update Preview Preserves Applied Provenance
The system SHALL preserve authoritative applied registry content during update dry run, including when source history advances without changing the selected profile digest. Explicit advisory update evidence SHALL remain distinct from applied provenance.

#### Scenario: New commit contains the same profile
- **WHEN** update dry run resolves a newer commit with unchanged profile content
- **THEN** the applied source, commit, timestamp, claims, and registry revision remain unchanged

