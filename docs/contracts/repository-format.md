# Montage repository envelope

Every native Montage repository has one root `montage.json`. The envelope
identifies the container and selects its validator; it is not a portable
loadout, a backup snapshot, an applied-state registry, or cleanup authority.

## Shared fields

| Field | Contract |
|---|---|
| `schemaVersion` | JSON integer; currently exactly `1` |
| `kind` | Exactly `montage-repository` |
| `repositoryType` | Exactly `loadouts` or `vault` |
| `id` | Stable 1–64 character lowercase id containing letters, digits, or interior hyphens; it begins and ends alphanumeric |
| `createdAt` | UTC timestamp formatted `YYYY-MM-DDTHH:MM:SSZ` |

Unknown, missing, or additional keys are rejected. An id is path-independent:
moving a repository does not change it, while replacing a configured path with
a repository carrying another id is detectable.

## Loadout repository

A schema-1 loadout envelope has exactly the shared fields:

```json
{
  "schemaVersion": 1,
  "kind": "montage-repository",
  "repositoryType": "loadouts",
  "id": "personal-loadouts-7d8f",
  "createdAt": "2026-10-06T20:00:00Z"
}
```

Portable items live below `loadouts/<stable-id>/profile.json`; they are not
embedded in this envelope.

## Vault repository

A schema-1 vault envelope adds `machineId`, another bounded stable id naming
the one machine lineage represented by the repository:

```json
{
  "schemaVersion": 1,
  "kind": "montage-repository",
  "repositoryType": "vault",
  "id": "vault-4a63d1",
  "createdAt": "2026-10-06T20:00:00Z",
  "machineId": "omarchy-laptop-12af"
}
```

The envelope is present in each valid backup commit. Backup-specific capture
metadata belongs in `backup.json`, not `montage.json`.

## Validation boundary

The CLI accepts only a regular, non-symlink `montage.json` with the exact
schema and repository kind expected by the operation. A string, expression,
fractional number, or future integer is not a schema version. Invalid ids are
rejected before they can select a path or Git ref.

## Configured repository registry

Montage records named repositories in
`${XDG_CONFIG_HOME:-~/.config}/montage/repositories.json`. Schema version 1 is
an exact object containing `schemaVersion`, a non-negative integer `revision`,
and a `repositories` array. Each repository entry contains exactly:

| Field | Contract |
|---|---|
| `name` | Unique bounded selector using the repository-id grammar |
| `path` | Canonical absolute path to a non-symlink directory |
| `type` | `loadouts` or `vault` |
| `id` | Expected stable id read from the envelope when configured |
| `remote` | Optional credential-free transport URL |

Changing a named entry to a repository with another id requires explicit
replacement. The registry does not grant trust to its path: every operation
revalidates the directory, envelope, expected kind, and expected id. Registry
writes reread under the Montage configuration lock and atomically increment the
revision. Removing an entry removes configuration only; it does not remove the
user-owned repository.

## Shared transaction boundary

One repository identity has one Montage state lock. Writers build a complete
candidate below a same-filesystem staging directory and invoke the loadout- or
vault-owned validator before moving the current destination. Publication uses
an identity-scoped recovery journal below the Montage state root. An interrupted
operation either restores the prior destination or finishes cleanup from the
recorded state; it does not silently treat a partial tree as published.

Git commits are created only when staged content changes. A clean-worktree
precondition prevents repository writers from absorbing unrelated user edits.
These mechanics do not define whether a loadout profile or backup is valid;
the domain contract and validator remain authoritative for that payload.

## Read and query boundary

Live controls are regular non-symlink files contained beneath the validated
repository. Stable ids are validated before constructing item paths. User Git
selectors are bounded ref names and resolve to one exact commit before use.
Historical trees are reconstructed from Git objects into an isolated Montage
state directory, reject unsupported object modes and escaping links, and
validate their own `montage.json`; querying history never checks out over or
dirties the configured working tree.

`mntg repository list`, `show`, and `validate` expose human-readable results or
one versioned JSON document. `configure` and `remove` are the only commands in
this surface that change the registry. These commands report invalid,
missing, type-mismatched, and identity-mismatched repositories without asking
the panel or another consumer to parse this file or inspect Git itself.

## Synchronization boundary

`mntg repository sync NAME` fetches into a Montage-owned observation ref and
classifies the exact local and remote commits as `equal`, `local-ahead`,
`remote-ahead`, or `divergent`. Inspection does not move the branch, index, or
working tree. Human output and versioned JSON or porcelain results expose the
repository id and kind, commits, ahead/behind counts, fetch status, requested
action, performed action, and failure or decision reason.

An explicit `--pull` permits only a clean-worktree, validated fast-forward.
An explicit `--push` permits only an ordinary non-forced push of unchanged
local-ahead history. Equal history is a successful no-op; divergence is a
decision, not an automatic merge. Montage never resets, rebases, merges
content, or force-pushes to resolve divergence. See the
[repository synchronization workflow](../workflows/repository-sync.md) for
transport, credential-helper, visibility, and resolution guidance.

Implementation ownership and extension rules are documented in the
[CLI module architecture](../architecture/cli-modules.md). Observable loadout,
vault, synchronization, and port behavior remains owned by its corresponding
OpenSpec capability and domain contract rather than being duplicated here.
