# Spec Delta

## Purpose

Defines machine-readable CLI surfaces used by the panel and automation so consumers receive stable records without parsing human prose.

## ADDED Requirements

### Requirement: Porcelain Output Is Protocol-Only
The system SHALL emit only defined protocol records on standard output when porcelain mode is active.

#### Scenario: Successful operation emits records
- **WHEN** a command runs with `--porcelain`
- **THEN** standard output contains structured step, progress, log, and completion records as applicable
- **AND** contains no decorative or explanatory prose

#### Scenario: Consumer sees skipped work
- **WHEN** an operation skips or defers a category in porcelain mode
- **THEN** the protocol reports that state instead of omitting it

### Requirement: JSON Commands Emit Valid JSON
The system SHALL emit one valid JSON result for commands that advertise JSON output, including meaningful fallback values when optional state cannot be parsed.

#### Scenario: Status consumer receives one object
- **WHEN** `ress status --json` completes
- **THEN** its standard output is a parseable JSON object

#### Scenario: Verify consumer receives item arrays
- **WHEN** `ress verify --json` completes
- **THEN** its result includes category summaries and structured item collections

### Requirement: Protocol And Human Output Remain Separable
The system SHALL keep protocol output free from prose while retaining human-readable explanations outside protocol mode.

#### Scenario: Human mode explains a warning
- **WHEN** a user runs a command without porcelain or JSON mode and a warning occurs
- **THEN** ress presents a readable explanation rather than requiring protocol interpretation

