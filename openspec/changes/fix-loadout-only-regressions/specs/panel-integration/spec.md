## ADDED Requirements

### Requirement: Valid Unhealthy Results Remain Usable
The panel SHALL preserve validated Loadout check results for the documented unhealthy exit status and SHALL reject malformed results or process failures separately.

#### Scenario: A package is missing
- **WHEN** the CLI returns valid unhealthy check JSON and exits with its health-result status
- **THEN** the panel shows the affected Loadout and corrective actions rather than discarding its view

### Requirement: Ress Consumer Matches The Producer Contract
The panel SHALL accept the CLI's versioned Ress migration result with explicit per-plugin decision values and SHALL refuse malformed decision data.

#### Scenario: Inspection succeeds
- **WHEN** Ress inspection emits a supported result
- **THEN** the panel presents its compatibility and decision data and permits the corresponding terminal handoff

