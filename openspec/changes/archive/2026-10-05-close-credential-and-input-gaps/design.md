# Design

## Context

See `proposal.md` for motivation. URL validation, credential stripping, vault scanning, manifest selection, profile fetching, and category parsing currently live in several modules. Some paths already sanitize sources or reject symlinked current exports, but capture/configuration and fetched control files do not consistently apply those rules. The change crosses confidentiality, network, and untrusted-filesystem boundaries without changing schema versions.

## Goals / Non-Goals

**Goals:**

- Establish one credential-free persistence/display rule for every URL-bearing workflow.
- Make the documented pre-commit scan cover the complete plaintext vault.
- Refuse untrusted scalar control files before following repository-created symlinks.
- Preserve private Git access for the immediate command without turning config or vault history into credential storage.

**Non-Goals:**

- Detect every possible secret value or replace dedicated secret scanning tools.
- Inspect age ciphertext or add a new secrets format.
- Ban SSH remotes from private vault workflows where they are already supported.
- Change loadout or vault schema versions.

## Decisions

### 1. Separate transport URLs from persisted/display URLs

Introduce safety helpers that identify URL user information and produce a credential-free URL. A command may keep the original value in a narrowly scoped variable long enough to clone, fetch, or push, but every value passed to config, vault inventories, profiles, registry state, status JSON, warnings, and generated instructions uses the sanitized form.

For Git remotes, removing user information preserves repository identity and allows later authentication through normal Git credential mechanisms. For web-app URLs, removal could change application semantics, so credential-bearing launchers and profile entries are refused instead of rewritten.

### 2. Scan the vault root with explicit exclusions

Both backup and `ress scan` invoke the same scanner on the vault root. The walk excludes `.git` directories and the known encrypted secrets bundle while retaining the existing binary skip, per-rule second pass, placeholder suppression, path-only findings, and warning/block/off modes. Scanning only an expanding allowlist of plaintext subtrees was rejected because each new capture category could silently fall outside the guarantee.

### 3. Sanitize before writing, not only before printing

Plugin/theme capture canonicalizes remotes before TSV output. `init`, `set REMOTE`, restore source adoption, profile-origin link generation, and status all share the same persistence rule. Sanitizing only at rendering time was rejected because credentials would remain in config, Git history, and later machine-readable output.

Credential-bearing web-app launchers are omitted from ordinary vault capture and reported in the existing capture-omission evidence. Public share catalog/profile normalization uses the same refusal predicate.

### 4. Centralize scalar control-file validation

Add a helper that receives an expected root and relative path, rejects symlinks and non-regular files, verifies lexical/canonical containment, and returns the safe path. Manifest/profile selection, TSV/list readers, launcher evidence, and encrypted-bundle selection use that helper before content parsing.

Captured directory trees continue using safe-link copy semantics because links can be legitimate evidence when they remain contained. Treating every tree link as a scalar control file was rejected because it would unnecessarily narrow existing safe-link behavior.

### 5. Refuse before mutation and report without secret material

Manifest and profile refusal occurs before compatibility arithmetic, planning, locking that creates visible mutation state, or external mutation. Error messages name the logical control file and reason but never echo the link target or credential-bearing URL. Tests assert both refusal and absence of the secret marker in combined stdout/stderr and persisted files.

## Risks / Trade-offs

- **[Private HTTPS remotes need credentials on later runs]** -> Store the credential-free remote and rely on Git's normal credential helper or SSH; document that embedded credentials are intentionally not retained.
- **[Whole-vault scanning increases work or false positives]** -> Keep one combined candidate walk, binary/encrypted exclusions, and placeholder suppression; record focused timing without weakening blocking semantics.
- **[Existing vault contains credential-bearing remotes]** -> Readers sanitize before display/use where safe and a subsequent backup rewrites inventories credential-free; no schema migration is needed.
- **[Strict scalar-file checks reject unusual local symlink layouts]** -> Apply them to fetched/control artifacts whose paths define authority; retain safe-link handling for ordinary captured trees.

## Migration Plan

1. Add regression fixtures for URL persistence/display, whole-vault findings, and symlinked control files.
2. Add shared URL credential and safe-control-file helpers with unit/integration coverage.
3. Route vault capture/config/status/restore and loadout profile/share paths through the helpers.
4. Expand the shared scanner root and exclusions, then reconcile contracts and workflows.
5. Run focused hostile-input, credential, remote, share, restore, and protocol cases; run the full suite, relevant mutation checks, and strict OpenSpec validation.

Existing schema-version-1 vaults, profiles, and registries remain readable when their control files are regular and values are safe. Rollback requires no data migration, though sanitized credentials are intentionally not recoverable from newly written state.
