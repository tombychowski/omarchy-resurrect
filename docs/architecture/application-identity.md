# Application identity and coexistence

Montage is an independent Omarchy plugin, not an in-place update of Ress. Its
plugin id, QML module, and IPC target are all `tombychowski.montage`. A Ress
installation under `tsouth89.resurrect` may remain installed; enabling,
updating, disabling, or removing either plugin does not target the other.

## Public command

The only Montage command is `mntg`. Montage does not install `ress`, which
belongs to the Ress project, or `montage`, which may already be ImageMagick's
command on an Omarchy machine.

From an installed plugin checkout, create the optional PATH link with:

```bash
~/.config/omarchy/plugins/tombychowski.montage/bin/mntg link
mntg doctor
```

`mntg link` creates `~/.local/bin/mntg` only when the path is absent or is
already the link owned by that active Montage installation. It refuses to
replace another file or symlink. Remove the owned link with:

```bash
mntg link --remove
```

Neither operation reads, replaces, or removes an existing `ress` or `montage`
command.

## Filesystem ownership

With the standard XDG defaults, Montage owns these roots:

| Root | Purpose |
|---|---|
| `~/.config/montage` | Configuration and user policy lists |
| `~/.local/state/montage` | Locks, operation markers, restore progress, scan findings, and applied-loadout state |
| `~/.local/share/montage` | Default user-owned vault and loadout data |
| `~/.local/bin/mntg` | Optional guarded link to the active CLI |

`XDG_CONFIG_HOME`, `XDG_STATE_HOME`, and `XDG_DATA_HOME` relocate the first
three roots in the usual way. Ordinary Montage startup does not read or write
the corresponding Ress roots. Sharing a live config, state, vault, loadout,
lock, or registry directory is unsupported; Ress interoperability is handled
only by the explicit port workflow documented with that feature.

## Consumer boundary

[`bin/mntg`](../../bin/mntg) and its modules under
[`lib/montage/`](../../lib/montage/) are the authority for product state and
mutation. `Panel.qml` and `Service.qml` address only the Montage IPC identity
and invoke `bin/mntg`; they do not discover or control Ress processes.
