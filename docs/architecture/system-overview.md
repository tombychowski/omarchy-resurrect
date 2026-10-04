# System overview

ress is a Bash CLI with a small QML panel and headless scheduling service. The CLI is the authority for persistent machine state; the QML layer reads stable outputs and delegates mutations back to the CLI.

## Components

### `bin/ress`

The CLI implements capture, restore, loadout sharing/application, verification, credential scanning, configuration, status, and supporting commands. It owns input validation, consent gates, locking, persistent progress, vault formats, and consumer output.

The CLI is the only component that reads or writes the vault as product state. Human output explains decisions; JSON and porcelain output serve automation and the panel.

### `Service.qml`

The service wraps CLI processes for the shell. A panel-owned instance refreshes `ress status --json`, launches backup/share with `--porcelain`, parses protocol records through `Model.js`, and exposes UI state. A headless instance schedules backups from CLI-owned config and state stamps.

It watches config and state files to know when to refresh presentation, but it does not inspect vault contents or implement restore logic.

### `Panel.qml`

The panel renders backup freshness, captured categories, progress, consent settings, and share/apply entry points. Backup and share can run in-panel through the CLI protocol. Restore and loadout apply open an interactive terminal because they may need privilege, review, or confirmation.

### `Model.js`

The model contains presentation-only helpers: freshness and relative-time labels, category descriptions, credential stripping for displayed remotes, consent wording, summaries, and line-protocol parsing. It has no filesystem or process access and is unit-tested under Node.

### Plugin manifest

`manifest.json` registers `Panel.qml` as the bar widget and `Service.qml` as the service entry point. The only panel setting declared there is the stale-backup threshold.

## Persistent state

| Location | Owner | Purpose |
|---|---|---|
| `~/.local/share/ress/vault` | CLI | Default private Git vault |
| `~/.local/share/ress/profile` | CLI | Default exported loadout repository |
| `~/.config/ress/config` | CLI; watched by QML | User settings and category choices |
| `~/.config/ress/include`, `exclude`, `aur-deny`, `secrets` | CLI | User extensions to curated policy lists |
| `~/.local/state/ress/` | CLI; selected stamps watched by QML | Last success/attempt, operation lock marker, restore progress, local scan findings |

The exact vault and profile formats are defined in [contracts](../contracts/).

## Data flow

### Backup

1. A user, the panel, or the scheduler invokes `ress backup`.
2. The CLI locks the operation, captures enabled categories, writes the manifest, scans captured content, and commits the vault when policy permits.
3. In porcelain mode, the CLI emits progress records; the panel displays them.
4. The CLI updates state stamps. File watchers and a status refresh update the panel.

### Restore

1. A user invokes restore directly or the panel opens it in a terminal.
2. The CLI obtains and validates the vault before mutation.
3. It previews planned and executable/persistent content, obtains required consent, and replays selected categories.
4. Completion state is recorded per snapshot so the operation can resume.
5. `ress verify` independently compares the resulting machine with restorable vault state.

### Loadout

`ress share` creates a fixed-schema `profile.json`. `ress apply` resolves the source, validates the profile, previews the four supported action types, confirms, and performs only missing actions. The panel hands preview/apply to a terminal rather than parsing the profile itself.

## External tools

The CLI composes existing Omarchy and Arch tools including Git, `jq`, `rsync`, `pacman`, `yay`, `systemctl --user`, `age`, and the `omarchy` CLI. Tests put doubles for these tools on `PATH`; real-machine and VM validation cover behavior the doubles cannot prove.

## Trust boundaries

- **Vaults and loadouts are untrusted input.** Names, paths, URLs, schema versions, commits, and launcher fields are validated before they reach commands or mutation.
- **AUR packages cross an execution boundary.** PKGBUILDs run on the machine, so their build decision is separate from ordinary restore confirmation.
- **User services cross a persistence boundary.** Enabling a service schedules future execution, so candidates and executable commands are shown before a separate decision.
- **Secrets cross a confidentiality boundary.** Ordinary capture excludes credential paths; the opt-in secrets path encrypts before storage and restores private permissions.
- **The panel crosses a consumer boundary.** It receives JSON or porcelain output from the CLI and must tolerate invalid output without inventing state.
- **Remote Git state crosses a network boundary.** Restorable shared code requires safe remotes and recorded commits unless the user explicitly accepts an unpinned head.

## Verification boundary

The automated suite proves command decisions and filesystem effects inside a sandbox. It does not prove real package installation, a service starting at login, a visible theme change, rendered panel behavior, or timing on a clean Omarchy installation. Those boundaries are documented in the [testing strategy](../testing/strategy.md).
