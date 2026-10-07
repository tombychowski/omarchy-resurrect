# Keyboard workflow

The panel uses the same row model for pointer and keyboard activation.

## Navigation

- Arrow keys move through rows and tabs; Enter activates the current row.
- `b` starts backup.
- `r` opens **Repositories** and asks for an exact vault backup selection.
- `o` opens **Repositories**.
- `s` opens **Share**.
- `a` or `l` opens **Loadouts**.
- Escape leaves every text field and returns focus to panel navigation.

On **Repositories**, select a repository row, then a stable loadout id or full
backup commit. **Compose selected loadout** opens Share. **Restore this exact
backup** opens a terminal pinned to that commit. Sync, retention, and port rows
always expose their read-only preview before the terminal action.

## Evidence classification

Automated evidence (`tests/model-test.js` and `tests/cases/16-qml.sh`) covers row
presence, focus escape handlers, state transitions, exact command arguments,
parser refusal, and QML syntax/type resolution.

Clean-Omarchy evidence is required for rendered tab width, scrolling, pointer
hit targets, visible keyboard cursor, focus return, terminal placement, and
screen-reader behavior. Release evidence should capture:

1. all four tabs at the target scale;
2. repository, loadout, and backup selection using keyboard only;
3. empty, invalid, loading, healthy, stale, divergent, and attention views;
4. selected-loadout Share composition; and
5. exact-restore, retention, sync, loadout-mutation, and port terminal handoffs
   before confirmation.

Screenshots are documentation evidence, not proof of CLI semantics. Record the
machine image/version, display scale, plugin commit, and expected observation
with each capture in the fresh-machine validation log.
