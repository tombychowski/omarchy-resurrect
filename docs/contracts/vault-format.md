# Vault repository and backup format

A Montage vault is a private Git repository for one machine lineage. Its
stable container identity lives in `montage.json`, its current snapshot is
described by `backup.json`, and earlier backups are immutable Git commits.
The default path is `~/.local/share/montage/vault`; `--vault DIR` selects
another native vault.

The `vault-repositories`, `vault-capture`, `credential-protection`,
`schema-compatibility`, and `untrusted-artifact-reading` OpenSpec capabilities
own the observable guarantees. [Repository envelope](repository-format.md)
defines the shared container fields.

## Repository and snapshot layout

```text
montage.json                     stable vault and machine-lineage identity
backup.json                      current snapshot metadata
README.md                        generated recovery hint
packages/
  native.txt
  foreign.txt
home/                             selected $HOME-relative configuration
omarchy/                          portable Omarchy state
webapps/apps/                     captured launcher evidence
webapps/icons/                    captured icons
plugins/plugins.tsv              plugin id, remote, enabled state, commit
services/user-units.txt           enabled systemd user-unit names
secrets/secrets.tar.age           optional encrypted archive
report/not-captured.txt           visible capture omissions
report/symlinks-skipped.txt       links not followed outside the boundary
.git/                             backup history and Montage labels
```

A native vault cannot contain a `loadouts/` collection or root
`profile.json`. Applied-loadout state, repository configuration, locks,
credentials, restore progress, and private encryption identities are also not
vault payload.

## Stable envelope

`montage.json` has `repositoryType: "vault"`, a stable repository `id`, and a
stable `machineId`. The ids do not change across backup commits or when the
repository moves. Every backup's `machineId` must equal the envelope lineage;
a crossed lineage, changed configured id, loadout envelope, malformed schema,
or future schema is refused before preview or mutation.

```json
{
  "schemaVersion": 1,
  "kind": "montage-repository",
  "repositoryType": "vault",
  "id": "vault-4a63d1",
  "createdAt": "2026-10-06T20:00:00Z",
  "machineId": "machine-12af89"
}
```

## Current `backup.json`

Schema version 1 is an exact object:

```json
{
  "schemaVersion": 1,
  "kind": "montage-backup",
  "montageVersion": "1.2.0",
  "createdAt": "2026-10-06T20:15:00Z",
  "machineId": "machine-12af89",
  "machine": {
    "hostname": "example",
    "user": "user",
    "omarchy": "unknown",
    "kernel": "..."
  },
  "categories": ["packages", "config", "omarchy", "webapps", "plugins"],
  "counts": {
    "packages": 0,
    "config": 0,
    "themes": 0,
    "webapps": 0,
    "plugins": 0,
    "secrets": 0,
    "uncaptured": 0,
    "services": 0
  }
}
```

Schema versions are JSON integers and must equal the supported version. The
category set is bounded and unique; counts are non-negative integers; machine
evidence is bounded display-safe text. Unknown keys do not grant behavior.
Payload files and inventories remain authoritative for replay.

## Capture transaction and exclusions

Backup holds the repository lock and requires a clean worktree. It builds a
complete candidate on the repository filesystem, captures enabled categories,
writes and validates `backup.json`, validates every contained control and
payload boundary, and then scans all candidate plaintext. A blocking finding
discards the candidate without changing the live snapshot or history.

Publication uses a recovery journal. An interruption before completion leaves
the old snapshot recoverable on the next backup. A changed candidate becomes
exactly one commit; when only `createdAt` would differ, Montage keeps the
existing commit rather than manufacturing backup history.

Capture excludes Montage configuration, state, locks, repository trees,
`~/.local/bin/mntg`, `.git` internals, and files ending `.montage-bak`.
Configured repositories nested below a broad capture root are neither copied
nor traversed for omission reporting.

## Payload ownership and safety

- `packages/` contains validated explicit package names and is replayed
  additively.
- `home/` is written from the curated include boundary after mandatory and
  user exclusions. Restore preserves replaced files with `.montage-bak`.
- `omarchy/` carries known shell and theme state. Remote code records a
  credential-free remote and exact commit when available.
- `webapps/` is validated evidence for reconstruction through Omarchy; a
  captured launcher is not blindly installed or executed.
- `plugins/plugins.tsv` is validated inventory, not shell input.
- `services/user-units.txt` is enabled-state evidence; enabling is a separate
  consent decision.
- `secrets/secrets.tar.age` is the only supported secret payload and remains
  ciphertext. Keys and recipient configuration stay local.
- `report/` explains omissions and never grants restore authority.

Controls must be contained regular non-symlink files. Historical trees are
materialized from Git objects into an isolated private directory. Unsupported
object modes, missing controls, symlinked controls, and links escaping that
tree are rejected. History inspection never checks out over the configured
working tree.

## Commit identity, labels, and retention

The full Git commit id is the backup identity. `mntg backup list` and
`mntg backup show COMMIT` validate each snapshot at that exact commit before
returning human or versioned JSON metadata. Mutable refs are resolved once
before preview; the isolated commit remains the only restore input even if a
branch moves afterward.

Montage-managed labels use bounded lowercase ids under a private Git ref
namespace. A label is unique and resolves to one validated commit. Labels on
backups selected for removal protect those backups until explicitly removed.

`mntg backup retain --keep COUNT --dry-run` lists the exact commits that would
leave local branch history. Confirmation is mandatory for a live rewrite.
Retained snapshots may receive replacement commit ids because severing linear
ancestry requires reconstructing the retained chain; retained labels are
remapped to the equivalent commits. If an upstream exists, Montage reports
that the rewritten local history will diverge. It never force-pushes retention
over published history.

## Restore and resume identity

Restore and verification accept `--backup COMMIT_OR_LABEL`; omitted selection
means `HEAD`, resolved immediately to a commit. Preview, confirmation, dry run,
verification, and category replay all name and use the same repository id and
resolved commit.

Live progress is private operational state at
`~/.local/state/montage/restore.state`. Its identity line contains the vault
repository id and exact backup commit, followed by completed categories.
Another repository or commit starts a new completion set; dry run writes no
progress. `--restart` explicitly discards progress for the selected backup.

## Private storage and compatibility boundary

A vault contains personal configuration, inventories, host evidence, and
possibly encrypted-secret ciphertext. Keep its remote private. Git credentials
come from the user's transport, agent, or credential helper and are never
stored in Montage configuration, output, or commits.

Ress manifests and suffixes are not native Montage controls. They are accepted
only by the explicit Ress port adapter, which writes a separate native
repository and leaves the source unchanged.

See [Restore safety](restore-safety.md),
[Back up and restore](../workflows/backup-restore.md), and
[Encrypted secrets](../workflows/encrypted-secrets.md).
