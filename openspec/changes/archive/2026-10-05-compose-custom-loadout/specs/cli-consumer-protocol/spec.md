# Spec Delta

## ADDED Requirements

### Requirement: Share Catalog Is A Stable Consumer Surface
The system SHALL provide one valid JSON share-catalog result containing stable resource identities, kinds, display metadata, shareability states and reasons, current-export metadata and membership, and applied-loadout preset membership.

#### Scenario: Panel requests the share catalog
- **WHEN** the share catalog JSON command completes successfully
- **THEN** standard output contains exactly one parseable JSON object
- **AND** each selectable or unavailable resource is represented as one structured record with a stable identity

#### Scenario: Optional preset state is unavailable
- **WHEN** applied-loadout state cannot be validated but current-machine discovery succeeds
- **THEN** the catalog reports applied-loadout presets as unavailable rather than fabricating an empty healthy list
- **AND** still reports independently validated machine candidates and current-export state

#### Scenario: Current export is absent or invalid
- **WHEN** the default profile does not exist or cannot be validated
- **THEN** the catalog distinguishes absent or unavailable current-export state from a valid empty selection

### Requirement: Selective Share Outcomes Are Machine-Readable
The system SHALL keep selective-share porcelain output protocol-only and SHALL report a qualified terminal outcome and affected resource identities when validation or acknowledgement prevents export.

#### Scenario: Selective export succeeds
- **WHEN** a valid non-empty selection is exported in porcelain mode
- **THEN** standard output contains only defined protocol records
- **AND** the terminal record reports success and the profile location

#### Scenario: Selection is refused
- **WHEN** an unknown, stale, unavailable, empty, or multi-theme selection is submitted in porcelain mode
- **THEN** protocol records identify the refused resource or selection condition
- **AND** the terminal record does not report unqualified success

#### Scenario: Withdrawal acknowledgement is required
- **WHEN** selective export would drop an unavailable current-profile resource without an identity-specific acknowledgement
- **THEN** the protocol reports that resource and the required acknowledgement state
- **AND** no prose is mixed into standard output

