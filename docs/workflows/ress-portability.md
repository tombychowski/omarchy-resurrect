# Port Ress v1 artifacts

Ress compatibility is a bounded interchange feature, not a shared-state mode.
Montage supports the documented Ress 1.2.0 schema-1 loadout and vault controls,
including the older `resurrect.json` manifest spelling. It does not read Ress
configuration or operational state during ordinary use and does not promise to
follow future Ress formats.

Ress v1 is the first adapter on Montage's format-neutral port lifecycle. The
documented `ress` command selector is a convenient alias for canonical format
id `ress-v1`; JSON and porcelain reports always identify `ress-v1`. Shared
destination, history-read, loss-consent, publication, and report rules are
documented in the [port adapter architecture](../architecture/port-adapters.md).

Always use disposable copies or distinct source and destination paths. Every
flow below starts with inspection and a dry run. Import never changes the Ress
source; export never changes a Montage repository or selected commit.

## Inspect first

```bash
mntg port ress inspect /path/to/ress-profile --json
mntg port ress inspect /path/to/ress-vault --json
mntg port ress plan /path/to/ress-vault \
  --destination "$HOME/.local/share/montage/imported-vault" --json
```

The versioned report names the artifact type and version, canonical source,
proposed destination, selected revisions, warnings, itemized losses, and planned
mutations. A future version, symlink, escaping path, malformed control, source
and destination overlap, or non-empty destination is refused rather than
treated as acceptable loss.

## Import one current loadout

First initialize and configure a separate Montage library, then preview:

```bash
mntg repository init loadouts "$HOME/.local/share/montage/loadouts" \
  --id personal-loadouts
mntg repository configure personal "$HOME/.local/share/montage/loadouts" loadouts
mntg port ress inspect /path/to/ress-profile --json
mntg --dry-run port ress import loadout /path/to/ress-profile \
  --repository personal --loadout workstation --json
```

Publish only after reviewing the report:

```bash
mntg port ress import loadout /path/to/ress-profile \
  --repository personal --loadout workstation
```

The portable `profile.json` remains schema-1 `omarchy-loadout` data. Montage
adds it as one new stable item and one new commit; it does not replace siblings,
inherit the Ress remote, or adopt applied-state ownership.

## Import the current vault snapshot

The default is one current snapshot and fresh Montage history:

```bash
mntg port ress inspect /path/to/ress-vault --json
mntg --dry-run port ress import vault /path/to/ress-vault \
  --destination "$HOME/.local/share/montage/imported-vault" \
  --ress-plugin omit --montage-plugin include --json
mntg port ress import vault /path/to/ress-vault \
  --destination "$HOME/.local/share/montage/imported-vault" \
  --ress-plugin omit --montage-plugin include
```

The destination must be absent or explicitly empty. Montage creates new
repository and machine-lineage ids, translates `ress.json` or `resurrect.json`
to `backup.json`, translates replacement suffixes to `.montage-bak`, and makes
one new commit. It inherits no remote or source commit identity.

## Optionally translate history

History translation is slower because every first-parent Ress revision is
materialized and validated in isolation before anything is published:

```bash
mntg port ress plan /path/to/ress-vault \
  --destination "$HOME/.local/share/montage/imported-history" \
  --history --json
mntg --dry-run port ress import vault /path/to/ress-vault \
  --destination "$HOME/.local/share/montage/imported-history" \
  --history --json
```

Any bad revision stops the default operation. To select the reported compatible
subset, accept only that itemized loss:

```bash
mntg --dry-run port ress import vault /path/to/ress-vault \
  --destination "$HOME/.local/share/montage/imported-history" \
  --history --compatible-only \
  --accept-loss unsupported-history-revisions --json
mntg port ress import vault /path/to/ress-vault \
  --destination "$HOME/.local/share/montage/imported-history" \
  --history --compatible-only \
  --accept-loss unsupported-history-revisions
```

The result maps source commits to new Montage commits. Source hashes and remotes
remain evidence only and are never claimed as native Montage history.

## Export a disposable Ress v1 copy

Inspect or query the exact native item first, then dry-run the export:

```bash
mntg repository loadout show personal workstation --json
mntg --dry-run port ress export loadout personal --loadout workstation \
  --destination /tmp/ress-workstation \
  --accept-loss montage-repository-metadata --json
mntg port ress export loadout personal --loadout workstation \
  --destination /tmp/ress-workstation \
  --accept-loss montage-repository-metadata
```

For a backup, inspect the exact commit before exporting it:

```bash
mntg backup show before-reinstall --json
mntg --dry-run --vault "$HOME/.local/share/montage/vault" \
  port ress export backup --backup before-reinstall \
  --destination /tmp/ress-backup \
  --accept-loss montage-vault-identity --json
mntg --vault "$HOME/.local/share/montage/vault" \
  port ress export backup --backup before-reinstall \
  --destination /tmp/ress-backup \
  --accept-loss montage-vault-identity
```

Exports contain only Ress v1 controls and representable payload in a separate,
validated directory. The destination is never implicitly overwritten.

## Loss and identity decisions

| Code or choice | Meaning | Can it be accepted? |
|---|---|---|
| `montage-repository-metadata` | A Ress loadout leaf cannot carry Montage repository id, stable selector, or commit provenance | Yes, by exact code |
| `montage-vault-identity` | Ress v1 cannot carry the native vault id, machine-lineage id, labels, or backup commit identity | Yes, by exact code |
| `unsupported-history-revisions` | The reported source commits are omitted from an explicitly selected compatible subset | Yes, by exact code |
| `--ress-plugin include\|omit` | Preserve or omit the Ress plugin as Ress; never silently map it to Montage | Explicit choice required when present |
| `--montage-plugin include\|omit\|map-ress` | Preserve, omit, or deliberately map the Montage plugin in a Ress export | Explicit choice required when present |
| Credentials, containment, private keys, execution consent, or cleanup ownership | Safety or authority cannot be represented safely | Never |

`--yes` confirms publication; it does not accept a loss or decide a self-plugin.
There is no wildcard loss acceptance.

Encrypted `secrets/secrets.tar.age` ciphertext may be copied byte-for-byte when
the target format can represent it. Encryption configuration, recipient
identity, passphrases, and private keys are never ported. Move a required
private identity through a separate secure channel.

## Manual copy fallback

If the adapter cannot identify an artifact, preserve the original and make a
separate working copy before investigating:

```bash
cp -a -- /path/to/ress-artifact /tmp/ress-artifact-working-copy
mntg port ress inspect /tmp/ress-artifact-working-copy --json
```

For a known schema-1 loadout, `profile.json` itself is the portable unit; it can
be copied into a newly initialized Montage repository at
`loadouts/<new-stable-id>/profile.json`, then checked with
`mntg repository validate`. Do not copy `.git`, Ress configuration, remotes,
locks, restore progress, keys, or applied ownership. For vaults, manual file
renaming alone is not enough to create `montage.json`, machine lineage, a valid
`backup.json`, or fresh history; use the inspected import path above.
