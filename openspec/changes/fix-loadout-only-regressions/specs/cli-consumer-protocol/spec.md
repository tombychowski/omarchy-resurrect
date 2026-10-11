## ADDED Requirements

### Requirement: Doctor Distinguishes State Directories From Files
The system SHALL evaluate writable state directories as directories and configuration files as files without reporting an existing writable state directory as unusable.

#### Scenario: State exists after apply
- **WHEN** doctor runs after successful apply with a writable nonsymlink state directory
- **THEN** the state-path check succeeds

