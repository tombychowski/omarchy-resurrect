# Tasks

## 1. Credential-Free URL Persistence And Display

- [x] 1.1 Add hostile URL fixtures for init/set/status, restore-source adoption, plugin/theme capture, profile origin/share output, and web-app capture/apply; verify each case asserts the secret marker is absent from stdout, stderr, config, vault, profile, registry, and generated instructions
- [x] 1.2 Add shared safety helpers that detect URL user information and derive credential-free Git URLs, and verify representative HTTPS username, password/token, port, path, query, fragment, SSH, and credential-free inputs without logging the original credential
- [x] 1.3 Route vault remote initialization/configuration/status and restore source adoption through separate transient-transport and persisted/display values, and verify private transport can use the supplied URL while stored and rendered state contains only the credential-free form
- [x] 1.4 Sanitize captured plugin/theme remotes and profile-repository origins before any TSV, profile, catalog, config, or instruction write, and verify share/capture fixtures retain repository identity without credential material
- [x] 1.5 Refuse credential-bearing web-app launchers and incoming profile entries before mutation, recording safe omission/refusal evidence that does not echo the URL; verify ordinary credential-free web-app behavior is unchanged
- [x] 1.6 Reconcile the URL rule in the CLI protocol, vault format, loadout profile/share, backup/restore, and encrypted-secrets documentation selected through `docs/index.md`, and verify the docs distinguish transient transport credentials from persisted values and explain web-app refusal

## 2. Whole-Vault Plaintext Scanning

- [x] 2.1 Add scanner fixtures with credential-shaped content outside `home/` and `omarchy/`, inside `.git`, inside the encrypted secrets bundle, in binary content, and as placeholders; verify warn/block/off behavior and path-only reporting for each boundary
- [x] 2.2 Make backup and `ress scan` call one vault-root scanner with explicit Git-metadata and encrypted-bundle exclusions, and verify a single candidate walk finds new plaintext categories without scanning excluded ciphertext or revealing matched values
- [x] 2.3 Update credential and vault/testing documentation for whole-vault scope and exclusions, and verify its examples match focused scan output and exit behavior

## 3. Untrusted Control Files

- [x] 3.1 Add hostile fetched-vault and loadout fixtures for symlinked manifests, profiles, inventories/lists, launchers, and encrypted bundles plus escaping links in captured directory trees; verify refusal happens before preview, locking, or external mutation
- [x] 3.2 Implement a shared safe-control-file resolver that accepts an expected root and relative path, rejects symlinks and non-regular files, proves containment, and returns only a validated path; verify unit/integration cases cover missing, regular, nested, absolute, traversal, and symlink inputs without exposing link targets
- [x] 3.3 Route manifest/profile selection and every scalar inventory, list, launcher, and encrypted-bundle reader through the resolver, and verify malformed artifacts fail consistently before parsing while supported legacy regular files remain readable
- [x] 3.4 Preserve existing safe contained directory replay while refusing links that escape the fetched subtree, and verify restore neither reads through the link nor derives a machine mutation target from it
- [x] 3.5 Reconcile vault-format, restore-safety, loadout-profile, workflow, and testing documentation with scalar control-file and directory-link rules, and verify every documented guarantee has a focused automated case or an explicit real-machine classification

## 4. Integration Evidence

- [x] 4.1 Run focused credential-scan, remote, share, web-app, hostile-vault, restore, and protocol cases, verifying all pass and a repository-wide search of their captured output/state finds no secret marker
- [x] 4.2 Run relevant mutation targets for URL sanitization/refusal, scan-root exclusions, control-file symlink rejection, and pre-mutation ordering, verifying each guard is killed by automated evidence
- [x] 4.3 Run `./tests/run.sh` and `openspec validate --all --strict`, verifying the full suite and every OpenSpec artifact pass; record any real-machine or fresh-VM-only evidence explicitly rather than weakening the guarantee
