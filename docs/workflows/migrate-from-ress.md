# Migrate a portable loadout from Ress

Montage can coexist with Ress and import one supported Ress v1 portable
loadout into a separate Montage library. It does not adopt or convert Ress
Backup/Restore state.

## Command and identity map

| Ress | Montage | Boundary |
|---|---|---|
| plugin `tsouth89.resurrect` | `tombychowski.montage` | separate installed products |
| `ress` | `mntg` | no command alias; ImageMagick retains `montage` |
| portable `profile.json` | portable `profile.json` | inspected schema-1 definition |
| Ress short link | configured library plus `--loadout ID` | no Ress service dependency |
| Ress apply state | Montage apply state | never copied; created by later native apply |

## Path map

Ress retains its own config, data, state, cache, command, repositories, and
history. Montage retains its own `~/.config/montage`,
`~/.local/share/montage`, `~/.local/state/montage`, and `~/.local/bin/mntg`.
Do not rename or move a Ress root into a Montage path.

## Install side by side

**Real-machine-only:** this lifecycle check requires an installed Omarchy shell.

```bash
omarchy plugin add https://github.com/tombychowski/omarchy-montage --enable
~/.config/omarchy/plugins/tombychowski.montage/bin/mntg link
command -v ress
command -v mntg
command -v montage
```

## Initialize native repositories

**Automated contract:** repository initialization and configuration are covered
by focused repository command and envelope cases.

```bash
mntg repository init "$HOME/.local/share/montage/loadouts" --id personal-library
mntg repository configure personal "$HOME/.local/share/montage/loadouts"
mntg repository list --json
```

Repository authentication belongs in a credential helper or SSH agent, never
URL user information.

## Inspect, preview, and import

**Automated contract:** frozen valid, hostile, future-version, decision, and
transaction fixtures cover these commands without touching the real machine.

```bash
mntg port ress inspect /path/to/ress-loadout --json
mntg --dry-run port ress import loadout /path/to/ress-loadout \
  --repository personal --loadout imported-work --json
mntg port ress import loadout /path/to/ress-loadout \
  --repository personal --loadout imported-work
```

If the inspection reports a Ress or Montage self-plugin entry, repeat preview
and import with the exact applicable `--ress-plugin include|omit` or
`--montage-plugin include|omit` decision. See [the focused migration
workflow](ress-portability.md).

## Why `profile.json` remains portable

Its fixed schema represents packages, pinned plugins, reconstructible web apps,
and one theme. It has no field for arbitrary files, commands, private keys,
runtime state, or cleanup authority. The destination repository supplies
Montage identity and history without rewriting the portable definition.

After migration, inspect and apply through native Montage behavior:

```bash
mntg repository loadout personal imported-work --json
mntg apply personal --loadout imported-work --dry-run
mntg apply personal --loadout imported-work
mntg loadout check
```

Only native apply observes the machine and creates claims. Migration itself
does not install packages or integrations.

## Roll back Montage without touching Ress

```bash
mntg link --remove
omarchy plugin remove tombychowski.montage
```

Ress files and command remain untouched. Montage libraries are user-owned Git
repositories; retain or remove them only after independent review.

## Private and non-portable material

Vaults, backups, history, remotes, configuration, locks, applied state,
credentials, private keys, executable authority, and cleanup ownership never
cross this boundary. Preserve such Ress material separately. There is no
Montage export or reverse-conversion command.
