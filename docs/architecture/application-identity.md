# Application identity and coexistence

Montage is an independent Omarchy plugin. Its plugin id, QML module, and IPC
target are `tombychowski.montage`; its only command is `mntg`. It does not
install `ress` or shadow ImageMagick's `montage` command.

Create or remove the guarded optional PATH link with:

```bash
~/.config/omarchy/plugins/tombychowski.montage/bin/mntg link
mntg link --remove
```

Montage changes `~/.local/bin/mntg` only when the path is absent or resolves to
the active installation. A foreign file or symlink is refused.

## Filesystem ownership

| Root | Purpose |
|---|---|
| `~/.config/montage` | AUR policy and configured loadout libraries |
| `~/.local/state/montage` | locks, operation marker, applied-loadout state, and advisory status evidence |
| user-selected paths | user-owned Montage loadout libraries |
| `~/.local/bin/mntg` | optional owned link |

The XDG config and state environment variables relocate the first two roots.
Montage does not read or mutate Ress-owned roots during ordinary operation.
Ress compatibility is an explicit read-only source selection followed by
publication to a separate Montage destination.

[`bin/mntg`](../../bin/mntg) and [`lib/montage/`](../../lib/montage/) remain the
authority. `Panel.qml`, `Service.qml`, and `Model.js` invoke and validate the
Montage CLI; they do not discover or control Ress state.
