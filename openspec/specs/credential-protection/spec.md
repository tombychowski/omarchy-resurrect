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
The system SHALL scan captured vault content for credential-shaped material before committing the backup and SHALL never print or persist the matched secret value.

#### Scenario: Warning mode reports a finding
- **WHEN** scanning finds credential-shaped material and scan mode is `warn`
- **THEN** backup identifies the affected file and finding type
- **AND** does not reveal the matching value

#### Scenario: Blocking mode prevents commit
- **WHEN** scanning finds credential-shaped material and scan mode is `block`
- **THEN** backup refuses to create the commit

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

