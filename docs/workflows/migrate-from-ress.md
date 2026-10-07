# Migrate from Ress to Montage

Montage is installed beside Ress and ports selected artifacts into separate
native repositories. It does not update the Ress plugin, adopt Ress paths, or
install a `ress` compatibility command.

## Command and identity map

| Ress | Montage | Notes |
|---|---|---|
| plugin id `tsouth89.resurrect` | `tombychowski.montage` | separate marketplace entries |
| `ress` | `mntg` | no alias; ImageMagick keeps `montage` |
| `ress backup` | `mntg backup` | writes only a native Montage vault |
| `ress restore` | `mntg restore --backup COMMIT` | prefer an exact native backup identity |
| `ress share` | `mntg share --repository NAME --loadout ID` | one selected item in a library |
| `ress apply SOURCE` | `mntg apply REPOSITORY --loadout ID` | stable selector is explicit |
| `ress status` | `mntg status` | Montage state only |
| Ress short link | canonical Git repository plus `--loadout ID` | no Ress service dependency |

## Path map

| Ress-owned path | Montage-owned path |
|---|---|
| `~/.config/ress/` | `~/.config/montage/` |
| `~/.local/share/ress/` | `~/.local/share/montage/` |
| `~/.local/state/ress/` | `~/.local/state/montage/` |
| `~/.cache/ress/` | `~/.cache/montage/` |
| `~/.local/bin/ress` | `~/.local/bin/mntg` |
| `*.ress-bak` | `*.montage-bak` |

Do not rename or move a live Ress directory into the Montage path. Native
controls, identity, history, locks, progress, and ownership have different
contracts. Port a disposable copy or use the source read-only.

## 1. Install side by side

**Real-machine-only:** Omarchy plugin lifecycle and PATH resolution require an
installed shell.

```bash
omarchy plugin add https://github.com/tombychowski/omarchy-montage --enable
~/.config/omarchy/plugins/tombychowski.montage/bin/mntg link
command -v ress
command -v mntg
command -v montage
```

Keep Ress enabled until native backups/loadouts have been inspected and tested.

## 2. Initialize native repositories

**Automated contract:** covered by `48-repository-envelope`,
`49-repository-registry`, `51-repository-commands`, and
`52-loadout-repository`.

```bash
mntg init
mntg repository configure laptop "$HOME/.local/share/montage/vault" vault
mntg repository init loadouts "$HOME/.local/share/montage/loadouts" --id personal-library
mntg repository configure personal "$HOME/.local/share/montage/loadouts" loadouts
mntg repository list --json
```

For GitHub, create the vault repository as **private**. Authentication belongs
in a Git credential helper or SSH agent, never URL userinfo:

```bash
mntg repository configure laptop "$HOME/.local/share/montage/vault" vault \
  --remote git@github.com:you/private-montage-vault.git --replace
mntg repository sync laptop --push
```

**Real-machine-only:** GitHub authentication and visibility observations.

## 3. Inspect before porting

**Automated contract:** covered by frozen-fixture cases `59`–`65`.

```bash
mntg port ress inspect /path/to/ress-loadout --json
mntg port ress inspect /path/to/ress-vault --json
mntg port ress plan /path/to/ress-vault \
  --destination "$HOME/.local/share/montage/imported-vault" --json
```

Inspection and planning do not write the source or destination. Resolve every
reported warning, unsupported revision, loss, credential, and self-plugin
decision before publication.

## 4. Import selected current artifacts

The current snapshot is the default and cheapest trust boundary:

```bash
mntg port ress import loadout /path/to/ress-loadout \
  --repository personal --loadout imported-work

mntg port ress import vault /path/to/ress-vault \
  --destination "$HOME/.local/share/montage/imported-vault"
```

Optional vault history translation validates each first-parent revision in
isolation and creates new Montage commits. A bad middle revision publishes
nothing by default. Compatible-subset publication requires the exact reported
loss acceptance; consult [Ress portability](ress-portability.md) rather than
copying an acceptance flag blindly.

After import:

```bash
mntg repository validate personal --type loadouts --json
mntg --vault "$HOME/.local/share/montage/imported-vault" backup list --json
```

## Why `profile.json` remains portable

The leaf filename and `kind: "omarchy-loadout"` remain because the constrained
schema safely represents packages, pinned plugins, reconstructible web apps,
and one theme without carrying arbitrary commands or cleanup authority.
Renaming the leaf would add product coupling without creating a safer format.

Montage-native library identity, stable selectors, remotes, and commits live in
the repository-level `montage.json`. Vaults use Montage-native manifests and
history because backup identity, restore progress, retention, and machine
lineage require semantics Ress v1 cannot represent.

## Verify, then choose whether to retire Ress

```bash
mntg repository list
mntg backup list
mntg loadout list --details
mntg loadout check
```

**Real-machine-only:** perform a disposable exact historical restore, selected
loadout apply, panel keyboard pass, and private GitHub sync before retirement.

## Roll back Montage without touching Ress

```bash
mntg link --remove
omarchy plugin remove tombychowski.montage
```

Ress remains installed with its original command and files. Montage native
repositories also remain user-owned; retain them for a later compatible
Montage version or remove them only after independent review. Do not downgrade a
repository envelope by editing its schema version.

## Manual copy fallback

If automation cannot inspect an artifact, copy it to disposable storage, retain
the original, and extract only documented portable leaves or payload after
independent validation. Never copy `.git`, remotes, configuration, locks,
restore progress, private keys, or applied ownership. Validate the separate
destination with `mntg repository validate` before use.
