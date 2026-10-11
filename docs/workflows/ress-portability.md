# Import a Ress v1 loadout

Montage has one frozen foreign-input boundary: it can inspect and import a
supported Ress v1 portable `profile.json` into one explicitly selected Montage
loadout library item. This is migration into Montage, not shared state or a
general conversion framework.

Montage does not import Ress vaults, backups, history, configuration, remotes,
locks, runtime state, applied claims, cleanup ownership, credentials, private
keys, or machine identity. It does not export anything to Ress.

## Prepare a Montage library

```bash
mntg repository init "$HOME/.local/share/montage/loadouts" --id personal-loadouts
mntg repository configure personal "$HOME/.local/share/montage/loadouts"
```

The destination must be a configured, valid, clean loadout repository. Choose
a new bounded lowercase stable id for the imported item; migration never
replaces an existing item implicitly.

The source tree and destination library must be separate: neither may contain
the other. Destination ancestors must be canonical nonsymlink directories.
Preview checks these boundaries and confirmed import checks them again while
holding the library lock.

## Inspect the source

```bash
mntg port ress inspect /path/to/ress-loadout --json
```

The source may be the containing directory or its contained regular
`profile.json`. A symlinked control, malformed or future-version profile,
credential-bearing URL, extra executable/ownership field, Ress vault, or
backup/history control is refused before a destination is changed. Other files
beside a valid profile are ignored with a warning and never become Montage
authority.

JSON inspection returns one `montage-ress-loadout-migration` object with:

- `format: "ress-v1"` and the source/supported schema versions;
- contained source identity and an optional selected destination identity;
- `compatible`, `ready`, and a bounded refusal or decision reason;
- warnings, itemized self-plugin losses, and exact decisions; and
- `publication.planned`, `publication.published`, and the resulting commit.

Inspection is read-only. Human output presents the same compatibility and
decision facts; porcelain uses `BEGIN|ress-migration|1`, `RESS|1`, optional
`RESS_LOSS` records, and one `DONE` record.

## Decide self-plugin entries explicitly

If the profile contains Ress or Montage itself, the result names the applicable
decision. `--yes` does not answer it.

```bash
mntg port ress inspect /path/to/ress-loadout \
  --ress-plugin omit --montage-plugin include --json
```

For each present self-plugin, choose exactly `include` or `omit`. There is no
implicit Ress-to-Montage mapping and no wildcard loss acceptance. Credentials,
private keys, executable authority, and cleanup ownership are invalid input,
not waivable losses.

## Preview and import one item

```bash
mntg --dry-run port ress import loadout /path/to/ress-loadout \
  --repository personal --loadout workstation \
  --ress-plugin omit --montage-plugin include --json

mntg port ress import loadout /path/to/ress-loadout \
  --repository personal --loadout workstation \
  --ress-plugin omit --montage-plugin include
```

Omit decision options that are `not-applicable`. Preview and live planning use
the same warnings, losses, decisions, compatibility, and destination identity.
The live command revalidates the unchanged source after confirmation, stages
one native profile, validates it, publishes it through the repository lock and
journal boundary, and creates one commit for the content change.

The source bytes, source Git state/remotes, destination envelope/remote,
sibling loadouts, and local applied-loadout registry remain unchanged. The
imported item gains no machine ownership until a later ordinary command such as:

```bash
mntg apply personal --loadout workstation --dry-run
mntg apply personal --loadout workstation
```

That apply observes the current machine and establishes native Montage
provenance and cleanup policy under the ordinary Loadout lifecycle.

## Manual fallback

If inspection refuses a source, retain the original. Do not make a native item
by copying Ress `.git`, remotes, configuration, locks, keys, vault material, or
ownership records. A portable profile can be investigated only on a disposable
copy, then must satisfy the same focused inspection before automated import.
