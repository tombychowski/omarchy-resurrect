# Montage loadout-library repository

Every native Montage repository is a multi-loadout Git library with one root
`montage.json`. The envelope identifies the library; it is not a portable
loadout, applied state, or cleanup authority.

## Native envelope

The envelope remains schema version 1 and has exactly these fields:

```json
{
  "schemaVersion": 1,
  "kind": "montage-repository",
  "repositoryType": "loadouts",
  "id": "personal-loadouts-7d8f",
  "createdAt": "2026-10-06T20:00:00Z"
}
```

`schemaVersion` is the JSON integer `1`; `kind` and `repositoryType` are the
fixed strings shown above. `id` is a stable 1–64 character lowercase id made
from letters, digits, and interior hyphens. `createdAt` is a UTC timestamp in
`YYYY-MM-DDTHH:MM:SSZ` form. Missing, additional, fractional, expression-like,
or future values are rejected.

A vault envelope, including one with `machineId`, is not a native Montage
repository. Normal commands reject it before inspecting payload or history.

Portable items live at `loadouts/<stable-id>/profile.json`. Moving a library
does not change its id. Replacing a configured path with another id requires
an explicit `--replace` after inspection.

## Configured repository registry

Montage records named libraries at
`${XDG_CONFIG_HOME:-~/.config}/montage/repositories.json`. The active document
is schema version 2 and has exactly `schemaVersion`, a non-negative integer
`revision`, and `repositories`:

```json
{
  "schemaVersion": 2,
  "revision": 9,
  "repositories": [
    {
      "name": "personal",
      "path": "/home/alex/.local/share/montage/loadouts",
      "type": "loadouts",
      "id": "personal-loadouts-7d8f",
      "remote": "https://github.com/example/personal-loadouts"
    }
  ]
}
```

Each entry has exactly:

| Field | Contract |
|---|---|
| `name` | Unique selector using the repository-id grammar |
| `path` | Canonical absolute path to a non-symlink directory |
| `type` | Fixed string `loadouts` |
| `id` | Expected stable id from the native envelope |
| `remote` | Optional credential-free Git transport URL |

Entries serialize in name order. Every operation revalidates the directory,
envelope, and expected id. Registry writes reread under the Montage
configuration lock, increment the revision, validate a complete temporary
document, and atomically replace the active file. Removing an entry changes
configuration only; it never removes repository content.

### Schema-1 migration

Schema 1 is recognized only at the configured-registry boundary. On first
read, Montage holds the configuration lock, rereads and validates the whole
legacy document, and fully validates every loadout entry. It classifies a
legacy vault entry from its `type` field without opening that entry's path.
Any invalid retained loadout aborts migration and names the entry; the active
file remains unchanged.

Before replacement, Montage creates this exact byte copy beside the registry:

```text
repositories.json.pre-schema2
```

The copy is a regular mode-0600 file, is never overwritten, and is inert during
normal runtime. Montage then writes one schema-2 document containing the
retained loadout entries in name order and increments the legacy revision once.
Mixed, loadout-only, vault-only, and empty valid schema-1 documents follow the
same rule. Concurrent readers serialize; an interruption before replacement
leaves schema 1 and its rollback copy retryable.

Human commands print a concise first-read notice. JSON results carry a
`migration` object with `performed`, `priorSchema`, `newSchema`,
`retiredVaults`, and `backup`. Porcelain results use the versioned `MIGRATION`
record documented in the [CLI protocol](cli-protocol.md). Reading schema 2 is
a no-op. A vault entry hand-added to schema 2 is malformed active state, not
another migration input.

To run a pre-change combined binary after code rollback, restore
`repositories.json.pre-schema2` to `repositories.json` while holding the
configuration lock. Repository content needs no rollback because registry
migration does not modify any library or retired vault path.

## Transaction and read boundaries

One library identity has one Montage state lock. Writers build a complete
candidate below a same-filesystem staging directory and run the loadout-item
validator before publication. An identity-scoped recovery journal allows an
interrupted publication to restore the prior item or finish exact cleanup.
Git commits are created only for content changes, and a dirty worktree blocks
publication.

Publication validates the canonical target and every existing destination
ancestor before creating directories or journals. Symlinked parents and
non-directory ancestors are refused; recovery applies the same checks.
Schema-1 publication journals retain the established `backup` field for the
temporary prior item. The interim `original` spelling is also readable with
identical strict path validation. Both describe transaction recovery content,
not a Backup/Restore product; mixed or unfamiliar journal keys are rejected.

Live controls are contained regular files. Stable ids are validated before
constructing paths. Historical trees are reconstructed from Git objects into
an isolated Montage state directory, reject unfamiliar modes and escaping
links, and validate their schema-1 loadout envelope. History reads never check
out over the configured worktree.

## Commands and synchronization

`mntg repository init PATH --id ID`, `configure NAME PATH`, `list`, `show`,
`validate`, `loadouts`, `loadout`, `remove`, and `sync` operate only on loadout
libraries. There is no repository-kind argument.

Synchronization fetches into a Montage-owned observation ref and classifies
the exact commits as `equal`, `local-ahead`, `remote-ahead`, or `divergent`.
Inspection does not move the branch, index, or worktree. `--pull` permits only
a validated clean-worktree fast-forward; `--push` permits only an ordinary
non-forced push of unchanged local-ahead history. Equal history is a no-op and
divergence requires a user decision. See the
[repository synchronization workflow](../workflows/repository-sync.md).
