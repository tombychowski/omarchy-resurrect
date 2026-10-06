# Spec Delta

## MODIFIED Requirements

### Requirement: Vault Is Scanned Before Commit
The system SHALL scan all captured plaintext vault content for credential-shaped material before committing the backup and SHALL never print or persist the matched secret value. Git metadata and the explicitly encrypted secrets bundle are outside the plaintext scan.

#### Scenario: Warning mode reports a finding
- **WHEN** scanning finds credential-shaped material and scan mode is `warn`
- **THEN** backup identifies the affected file and finding type
- **AND** does not reveal the matching value

#### Scenario: Blocking mode prevents commit
- **WHEN** scanning finds credential-shaped material and scan mode is `block`
- **THEN** backup refuses to create the commit

#### Scenario: Finding is outside configuration subtrees
- **WHEN** credential-shaped plaintext is captured in a launcher, inventory, report, or other vault subtree outside ordinary configuration and Omarchy content
- **THEN** backup and explicit scan inspect and report that finding under the same warning or blocking policy

#### Scenario: Encrypted secret bundle is present
- **WHEN** the vault contains the explicitly enabled age-encrypted secrets bundle
- **THEN** the plaintext scanner does not treat ciphertext as inspectable plaintext
- **AND** does not weaken the encryption requirement for that bundle

## ADDED Requirements

### Requirement: URL Credentials Are Ephemeral
The system SHALL NOT persist or display credentials embedded in a network URL and SHALL retain such credentials only for the immediate authorized transport operation that received them.

#### Scenario: Vault remote contains credentials
- **WHEN** a user supplies a credential-bearing vault remote for initialization or restore
- **THEN** ress may use the supplied URL for that immediate network operation
- **AND** stores and displays only its credential-free form

#### Scenario: Captured Git remote contains credentials
- **WHEN** a captured plugin or theme checkout has a credential-bearing origin
- **THEN** the vault records only the credential-free remote when it remains otherwise safe
- **AND** no warning or generated output reveals the removed credential

#### Scenario: Credential-bearing launcher cannot be preserved safely
- **WHEN** an ordinary web-app launcher URL contains embedded credentials
- **THEN** ress excludes it from plaintext capture and reports the omission without revealing the credential
