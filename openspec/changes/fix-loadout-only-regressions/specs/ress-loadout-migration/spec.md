## ADDED Requirements

### Requirement: Import Source And Library Trees Do Not Overlap
The system SHALL refuse Ress import when source and destination library trees overlap, including source ancestors or descendants of the library, and SHALL revalidate destination safety before publication.

#### Scenario: Library is inside the source
- **WHEN** the selected library is inside the Ress source tree
- **THEN** import preview and confirmed import refuse without changing either tree

#### Scenario: Destination parent redirects to source
- **WHEN** a destination ancestor is symlinked into the Ress source
- **THEN** import refuses before staging or writing library content

