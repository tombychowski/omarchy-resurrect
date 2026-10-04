# Vault format

A ress vault is an ordinary Git repository containing a versioned, portable description of one Omarchy machine. The default location is `~/.local/share/ress/vault`; `--vault DIR` selects another local vault. A remote is optional and should be private when the vault contains personal configuration or encrypted secrets.

This document describes the current schema written by ress 1.2.0. The authoritative behavior is specified by the `vault-capture`, `credential-protection`, and `schema-compatibility` OpenSpec capabilities.

## Top-level layout

```text
ress.json                         canonical manifest
README.md                         generated restore hint
packages/
  native.txt                     explicit repository packages
  foreign.txt                    explicit foreign/AUR packages
home/                             selected $HOME-relative configuration
omarchy/                          portable Omarchy state
  shell.json                     captured bar layout, when present
  themes/                        copied local themes
  theme-repos.tsv                remotely reconstructible themes
  current-theme                  active theme name
  hooks/ extensions/ branding/   captured Omarchy state, when present
webapps/
  apps/                           captured launcher evidence
  icons/                          captured application icons
plugins/
  plugins.tsv                     plugin id, remote, enabled state, commit
services/
  user-units.txt                 enabled systemd user-unit names
secrets/
  secrets.tar.age                optional encrypted archive
report/
  not-captured.txt               unlisted configuration directories
  symlinks-skipped.txt           links not followed outside the boundary
```

Directories can be absent or their list files empty when a category is disabled, unavailable, or has no entries. Consumers must use the manifest and tolerate empty categories rather than infer corruption from an empty list.

## Manifest

New backups write `ress.json`. Its current shape is:

```json
{
  "schemaVersion": 1,
  "ressVersion": "1.2.0",
  "createdAt": "2026-10-03T12:00:00Z",
  "machine": {
    "hostname": "example",
    "user": "user",
    "omarchyVersion": "unknown",
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

`schemaVersion` is the compatibility gate. ress accepts it only as a plain non-negative integer of bounded length and requires the supported version before restore. It must never be evaluated as shell or arithmetic input before validation.

`categories` records categories completed during capture. `counts` summarizes captured entries for status and presentation; the category payloads remain authoritative for replay.

## Payload ownership

Each subtree has one writer and one reconstruction path:

- `packages/` is written from explicit package databases and replayed additively.
- `home/` is written from the curated include boundary after mandatory and user exclusions. Restore writes paths relative to `$HOME` with safe-link and replacement-backup behavior.
- `omarchy/` is written from known Omarchy state. Repository-backed themes carry their remote and exact commit; local themes can travel as files.
- `webapps/` preserves enough evidence to rebuild supported launchers through the Omarchy CLI. A captured `.desktop` file is not executed or blindly installed.
- `plugins/plugins.tsv` records inventory. Only entries with safe, remotely cloneable sources and valid commits are reconstructible by default.
- `services/user-units.txt` records enabled-state names; `.wants/` link farms are not copied. Enabling on another machine requires separate consent.
- `secrets/secrets.tar.age` is produced only by the explicit secrets category and is never part of `home/`.
- `report/` is evidence about omissions. It is not a restore instruction.

Tab-separated inventories are parsed as data, then validated before values reach external commands. Invalid names, paths, URLs, commits, units, or launcher fields are refused rather than interpreted.

## Configuration boundary

Ordinary configuration capture is an allowlist assembled from the shipped `defaults/include.txt` plus the user's `~/.config/ress/include`. Exclusions combine `defaults/exclude.txt` and the user's `~/.config/ress/exclude`.

Mandatory exclusions protect credential-shaped paths and ress replacement backups even when a user broadens the include set. Capture uses safe-link handling and a size boundary for ordinary dotfile and Omarchy content. Unknown directories and skipped unsafe links are recorded in `report/` so absence is visible on the source machine.

Autostart launchers are excluded unless `CAPTURE_AUTOSTART=1`; enabling capture is explicit because those files arrange execution at the next login.

## Secret-bearing paths

The plaintext vault trees must not contain private keys or other mandatory credential exclusions. Captured plaintext content is scanned before commit according to `SECRET_SCAN`:

- `warn` identifies the affected path and finding type without recording the matched value, then permits the commit.
- `block` refuses to commit while findings remain.
- `off` disables the heuristic scan but does not disable mandatory path exclusions.

Local scan findings live under `~/.local/state/ress/`, not inside the vault. The opt-in secrets bundle is age ciphertext; selected secret paths and encryption configuration remain outside the vault.

## Compatibility

`ress.json` is canonical. The supported legacy manifest name is `resurrect.json`; status and restore can read it under the same schema rules. A later successful backup writes `ress.json` and removes the obsolete manifest name.

Both `.ress-bak` and the legacy `.resurrect-bak` suffix are excluded from subsequent capture so restore leftovers do not recursively enter the vault. New replacements use `.ress-bak`.

A schema newer than the CLI supports, a non-numeric schema, or malformed JSON is refused before machine mutation. Compatibility is explicit; consumers must not guess at future fields or execute migration content from a vault.

## Security assumptions

A vault fetched from a remote is untrusted input even when it belongs to the user. Git transport retrieves bytes; it does not make package names, paths, launcher commands, unit names, or repository URLs safe. The restore path validates each externally meaningful value and previews executable or persistent content before consent.

See [Restore safety](restore-safety.md) for mutation rules and [Encrypted secrets](../workflows/encrypted-secrets.md) for the opt-in workflow.
