# Panel CLI integration

The panel and headless service are CLI consumers. They provide native Omarchy presentation and scheduling without owning vault behavior, restore rules, or another machine-state model.

## Entry points

`manifest.json` registers:

- `Panel.qml` as the `bar-widget` entry point; and
- `Service.qml` as the headless `service` entry point.

The panel creates its own `Service` instance with `panelOwned: true`. Omarchy can also mount the service entry point headlessly for scheduled backups. These instances share no in-memory state; they converge on CLI-owned configuration and state files.

## Locating and invoking the CLI

`Service.qml` resolves `bin/ress` relative to the installed plugin. Process commands are constructed as argument arrays, not shell strings.

In-panel operations call:

```text
<plugin>/bin/ress --porcelain backup
<plugin>/bin/ress --porcelain share
```

The service clears prior transient operation state, launches one worker, and rejects another panel-owned operation while it is busy. The CLI's own lock remains authoritative across panel, terminal, scheduler, and direct CLI invocations.

## Status refresh

The panel-owned service runs:

```text
<plugin>/bin/ress status --json
<plugin>/bin/ress loadout list --json --contents
<plugin>/bin/ress loadout check --json
```

It collects stdout to completion and then parses one JSON object from each command. Stored inventory/content and live check results are validated independently and merged only by stable loadout identity. A non-zero check exit is expected when drift exists, so valid JSON still drives the panel. A parse failure or unmatched identity makes loadout state unavailable; no QML code falls back to reading the vault or loadout registry.

Status provides manifest counts and configured state. Freshness and relative age use the CLI-owned `last-backup` timestamp watched from `~/.local/state/ress/`. The panel also watches:

- `~/.config/ress/config` for category, schedule, remote, and consent settings;
- `last-attempt` for schedule calculations; and
- `running` for an operation owned by another ress process.

Watching these small files avoids polling or interpreting vault contents. A refresh occurs when the panel opens and after an in-panel worker exits.

## Porcelain consumption

Worker stdout is split by line and passed to `Model.parseRecord`. Recognized records update only transient presentation state:

- `STEP` sets current category/step, records the log entry, and captures step failure text;
- `PROGRESS` sets a numeric fraction when total is positive;
- `LOG` appends a note to the bounded activity log; and
- `DONE` stores the terminal state.

Unknown or human prose lines return `null` and are ignored. Embedded pipes are retained in message fields. The exact record grammar is defined by the [CLI protocol contract](../contracts/cli-protocol.md).

When the worker exits, the service clears busy progress, records stderr or a fallback exit-code error when needed, emits `finished(action, state)`, and refreshes status. The panel translates successful backup/share completion into brief notices and other terminal states into “finished with problems”; detailed failures remain available from the CLI message/error.

## Restore and loadout terminal handoff

The panel does not run restore or loadout apply inside the background worker.

- Restore launches `omarchy-launch-terminal <cli> restore` and closes the panel.
- Loadout preview launches `omarchy-launch-terminal <cli> apply --dry-run -- <url>`.
- Loadout apply launches `omarchy-launch-terminal <cli> apply -- <url>` and closes the panel.
- Update launches `omarchy-launch-terminal <cli> loadout update <id>`.
- Repair launches `omarchy-launch-terminal <cli> loadout repair <id>`.
- Removal launches `omarchy-launch-terminal <cli> loadout remove <id>`.

Commands are argument arrays and pasted sources follow a `--` boundary. The terminal keeps preview, `sudo`, AUR review, modified-resource decisions, destructive confirmation, and service consent visible and interactive. QML never deletes a resource or silently supplies `--yes`.

## Settings dispatch

Category and policy edits call `ress set KEY=VALUE` through detached argument-array processes. QML does not rewrite the config file. The CLI validates supported keys and values, locks the config update, re-reads current content under that lock, and writes the result.

The panel's default category display mirrors CLI defaults for a never-configured machine: packages, config, Omarchy, web apps, and plugins on; secrets off. Unknown consent values are presented as `ask`, matching the conservative CLI fallback.

## Scheduling

Only the headless service instance schedules backups. It computes a deadline from the later of the last successful backup and last attempt, preventing a failing scheduled backup from immediately retriggering in a tight loop.

When due, the service calls the same porcelain backup path as the panel. The CLI owns locking, capture, scanning, commit, push, and state stamps. The scheduler does not claim success until the CLI process reports and exits.

The panel-owned instance never starts the headless timer. It only displays `externallyBusy` when another ress process has created the running marker.

## Error rules

- Invalid status JSON is discarded, not partially merged with old or invented fields.
- Worker stderr becomes `lastError`.
- A non-zero exit without stderr becomes `exited with code <n>`.
- A `STEP` failure is shown immediately and retained in the operation log.
- An unknown protocol record does not mutate presentation state.
- The panel never retries a failed machine mutation on its own.
- Status freshness remains separate from operation errors.

## Keyboard and IPC

`PanelKeyCatcher` owns navigation, activation, closing, tab switching, and direct action shortcuts while the URL field does not have focus. Escape returns focus from the URL field. The panel also exposes IPC handlers for open, close, toggle, backup, and opening a named tab; IPC backup still delegates to `engine.backupNow()` and the CLI.

## Verification

- `tests/model-test.js` verifies parsing, freshness, consent language, loadout lifecycle/resource-health language, malformed handling, credential stripping, and category metadata.
- `tests/cases/12-porcelain.sh` verifies CLI stdout contains only defined records and reports deferred/failed work.
- `tests/cases/16-qml.sh` runs model tests, QML lint when available, and cross-checks every `engine.<member>` reference against `Service.qml`.
- A clean Omarchy VM remains required to verify rendering, focus, bar mounting, clicks, and terminal handoff end to end.
