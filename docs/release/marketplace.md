# Montage marketplace submission

This repository is submitted as a new Omarchy plugin. It does not update,
replace, rename, or claim the published `resurrect` listing.

## Listing metadata

| Field | Value |
|---|---|
| Plugin id | `tombychowski.montage` |
| Display name | Montage |
| Initial independent version | `1.0.0` |
| Repository | `https://github.com/tombychowski/omarchy-montage` |
| Homepage | `https://github.com/tombychowski/omarchy-montage` |
| Kinds | `bar-widget`, `service` |
| CLI | `mntg` |
| Category | System |
| License | MIT |

`manifest.json` is the machine-readable source for identity, entry points, bar
defaults, aliases, description, homepage, and version. The marketplace must
index this repository URL and plugin id as a new entry.

## Install, update, remove

```bash
omarchy plugin add https://github.com/tombychowski/omarchy-montage --enable
~/.config/omarchy/plugins/tombychowski.montage/bin/mntg link

omarchy plugin update tombychowski.montage

mntg link --remove
omarchy plugin remove tombychowski.montage
```

These commands never target `tsouth89.resurrect`, `ress`, or Ress-owned data.
User-owned Montage repositories and XDG state are retained on plugin removal.

## Release assets

Use Montage-specific names for uploaded assets so they cannot be mistaken for
predecessor releases:

- `omarchy-montage-1.0.0.tar.gz`
- `omarchy-montage-1.0.0-checksums.txt`
- `montage-panel-1.0.0.png`
- `montage-repositories-1.0.0.png`
- `montage-share-1.0.0.png`
- `montage-open-graph-1.0.0.jpg`

Screenshots must show current Montage branding and the `tombychowski.montage`
plugin. Do not reuse an asset whose visible content or metadata identifies Ress.

## Submission checks

```bash
omarchy-plugin-validate .
./tests/run.sh qml
./tests/run.sh structure
./tests/run.sh
openspec validate --all --strict
```

The marketplace submission should occur only after the full suite, strict
OpenSpec validation, active-source branding audit, and fresh-machine evidence
are complete.
