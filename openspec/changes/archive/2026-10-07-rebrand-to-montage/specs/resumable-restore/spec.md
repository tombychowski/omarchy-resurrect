## MODIFIED Requirements

### Requirement: Restore Preview Before Mutation

The system SHALL identify the selected vault repository and immutable backup commit, describe the backup contents, planned category actions, and executable or persistent content, and request confirmation before a live restore.

#### Scenario: Live restore presents a preview

- **WHEN** a user starts `mntg restore` from a valid selected backup
- **THEN** Montage lists the repository, commit and label when present, and work it plans to perform before modifying the machine
- **AND** requests confirmation unless an applicable explicit option already supplies it

### Requirement: Resumable Progress

The system SHALL persist completion progress for one immutable backup identity, including the vault repository identity and commit, so an interrupted restore can continue without repeating completed categories or drifting to another snapshot.

#### Scenario: Interrupted restore resumes

- **WHEN** a restore stops after one or more categories complete and is rerun against the same repository and backup commit
- **THEN** completed categories are skipped
- **AND** remaining categories are offered or executed

#### Scenario: Changed snapshot does not reuse stale progress

- **WHEN** the selected repository or backup commit differs from the identity associated with saved restore progress
- **THEN** Montage does not treat the selected backup's categories as already complete

#### Scenario: Mutable selector changes after preview

- **WHEN** a branch, label, or current-backup selector resolves to a different commit between preview and confirmed execution
- **THEN** Montage stops and requires a new preview and confirmation for the newly resolved commit
