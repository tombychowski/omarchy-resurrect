# credential-protection Specification

## Purpose

Defines how ress prevents accidental credential capture while providing an explicit encrypted path for secrets the user deliberately selects.

## Requirements

### Requirement: Credentials Are Excluded From Plain Capture
The system SHALL apply mandatory credential exclusions to ordinary configuration capture regardless of user include patterns.

#### Scenario: Private key is not captured as a dotfile
- **WHEN** a private key is located below an otherwise included directory
- **THEN** ordinary backup does not copy it into the plaintext vault tree

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

### Requirement: Secret Transport Is Explicit And Encrypted
The system SHALL keep the secrets category disabled by default and SHALL store selected secrets in the vault only as age-encrypted ciphertext.

#### Scenario: Default backup skips secrets
- **WHEN** the user has not enabled or forced the secrets category
- **THEN** backup does not create a secrets bundle

#### Scenario: Recipient mode supports unattended backup
- **WHEN** recipient mode names a valid public-key file
- **THEN** backup encrypts the selected secret paths without requiring an interactive passphrase

#### Scenario: Passphrase mode requires interaction
- **WHEN** passphrase mode runs without a usable terminal
- **THEN** ress skips or refuses the secret operation rather than storing a passphrase or plaintext

### Requirement: Decryption Preserves Private Permissions
The system SHALL restore decrypted secret files with private directory and file permissions.

#### Scenario: Secret is restored
- **WHEN** a valid encrypted bundle is restored with the required identity or passphrase
- **THEN** secret directories and files are written with private permissions
