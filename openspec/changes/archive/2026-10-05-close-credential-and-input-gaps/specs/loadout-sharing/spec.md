# Spec Delta

## ADDED Requirements

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
