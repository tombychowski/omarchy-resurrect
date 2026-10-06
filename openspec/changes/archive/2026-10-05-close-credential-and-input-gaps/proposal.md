# Proposal

## Why

Credential-bearing URLs can currently be persisted or printed by vault and configuration workflows, the credential scanner covers only two plaintext vault subtrees, and cloned control files can be followed through symlinks outside their untrusted artifact root. These discrepancies cross confidentiality and untrusted-input boundaries already described by the product guarantees.

## What Changes

- Apply one rule to every network source: credentials may be used transiently for an immediate request but are stripped before display, configuration, vault, profile, registry, or generated-link persistence.
- Scan the complete plaintext vault before commit and through `ress scan`, while excluding Git metadata and encrypted secret ciphertext.
- Refuse public loadout candidates and profiles whose web-app URLs contain credentials rather than silently changing the URL's meaning.
- Read manifest, profile, inventory, and encrypted-blob control files only when they are regular non-symlink files contained beneath the expected vault or cloned-profile root.
- Preserve safe-link behavior for captured directory trees while making scalar control-file refusal explicit and visible before mutation.
- Add hostile fixtures for credential-bearing remotes and web-app URLs, symlinked manifests/profiles/inventories, and findings outside `home/` and `omarchy/`.
- Reconcile credential, vault, loadout, restore, and testing documentation with the strengthened behavior.

## Capabilities

### New Capabilities

- `untrusted-artifact-reading`: defines containment and regular-file requirements for control files read from fetched vaults and loadouts.

### Modified Capabilities

- `credential-protection`: extend pre-commit scanning to all plaintext vault content and prohibit credential-bearing URL material from persisted or displayed state.
- `loadout-sharing`: refuse credential-bearing public resource URLs and keep catalog, profile, configured share URL, and generated output free of URL credentials.

## Impact

- **CLI safety and transport:** `lib/ress/safety.sh`, vault capture/common/restore/verify commands, and loadout profile/share paths.
- **Configuration and formats:** stored remote/profile URLs remain credential-free; no schema version changes are required because only accepted values and sanitization are tightened.
- **Contracts and workflows:** vault format, loadout profile, restore safety, CLI protocol, backup/restore, share/apply, and encrypted-secrets documentation.
- **Automated evidence:** credential scan, plugin remote, hostile vault, loadout composition, and new untrusted-control-file cases.
- **Compatibility:** credential-free URLs and regular control files remain compatible; unsafe credential-bearing public URLs and symlinked control files are refused before mutation.
