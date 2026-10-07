# System overview

Montage is a Bash CLI with a small QML panel and headless scheduling service. The CLI is the authority for persistent machine state; the QML layer reads stable outputs and delegates mutations back to the CLI.

## Components

### CLI: `bin/mntg` and `lib/montage/`

The CLI is one Bash program: `bin/mntg` is its only executable entrypoint and
loads the implementation modules under `lib/montage/` into the same process. It
implements capture, restore, loadout sharing/application and lifecycle
management, verification, credential scanning, configuration, status, and
supporting commands. Together, the entrypoint and modules own input validation,
resource inspection, consent gates, locking, persistent progress, vault and
registry formats, cleanup adapters, and consumer output. See the
[CLI module architecture](cli-modules.md) for file ownership and extension
guidance.

The internal file split does not change the consumer boundary: the CLI is the
only component that reads or writes the vault as product state. Human output
explains decisions; JSON and porcelain output serve automation and the panel.

### `Service.qml`

The service wraps CLI processes for the shell. A panel-owned instance refreshes
status, configured repositories, selected loadout or backup history, sync and
retention previews, selected-loadout Share state, Ress port previews, and
applied-loadout health through versioned `mntg` JSON. It merges only validated
CLI records by stable identity. It launches backup/share with `--porcelain` and
exposes UI state. A headless instance schedules backups from CLI-owned config
and state stamps.

It watches config and state files to know when to refresh presentation, but it does not inspect vault contents or implement restore logic.

### `Panel.qml`

The panel renders backup freshness, repositories, loadout libraries, immutable
backup history, sync state, settings, sharing, Ress port previews, and an
applied-loadout inventory. Backup and share can run in-panel through the CLI
protocol. Exact restore, retention, synchronization decisions, loadout
mutation, repository configuration, and port publication open an interactive
terminal because they may need privilege, destructive review, history or loss
decisions, and independent consent.

### `Model.js`

The model contains presentation-only helpers: freshness and relative-time labels, category descriptions, credential stripping for displayed remotes, consent wording, summaries, and line-protocol parsing. It has no filesystem or process access and is unit-tested under Node.

### Plugin manifest

`manifest.json` registers `Panel.qml` as the bar widget and `Service.qml` as the
service entry point. The shell-level widget setting is the stale-backup
threshold; repository settings are validated and serialized through `mntg
repository configure` from the Repositories tab.
The plugin, QML module, and IPC target all use `tombychowski.montage`; they do
not reuse the published Ress plugin identity. See [Application identity and
coexistence](application-identity.md).

## Persistent state

| Location | Owner | Purpose |
|---|---|---|
| `~/.local/share/montage/vault` | CLI | Default private Git vault |
| `~/.local/share/montage/profile` | CLI | Default exported loadout repository |
| `~/.config/montage/config` | CLI; watched by QML | User settings and category choices |
| `~/.config/montage/include`, `exclude`, `aur-deny`, `secrets` | CLI | User extensions to curated policy lists |
| `~/.local/state/montage/loadouts.json` | CLI; queried through CLI by QML | Applied-loadout snapshots, resource provenance, claims, and operation journal |
| `~/.local/state/montage/` | CLI; selected stamps watched by QML | Last success/attempt, operation lock marker, restore progress, local scan findings |

The exact vault and profile formats are defined in [contracts](../contracts/).

## Data flow

### Backup

1. A user, the panel, or the scheduler invokes `mntg backup`.
2. The CLI locks the operation, captures enabled categories, writes the manifest, scans captured content, and commits the vault when policy permits.
3. In porcelain mode, the CLI emits progress records; the panel displays them.
4. The CLI updates state stamps. File watchers and a status refresh update the panel.

### Restore

1. A user invokes restore directly or the panel opens it in a terminal.
2. The CLI obtains and validates the vault before mutation.
3. It previews planned and executable/persistent content, obtains required consent, and replays selected categories.
4. Completion state is recorded per snapshot so the operation can resume.
5. `mntg verify` independently compares the resulting machine with restorable vault state.

### Loadout

`mntg share` creates a fixed-schema `profile.json` in one current profile
repository. Its canonical candidate collector supplies both legacy whole-machine
export and `mntg share catalog --json`; selective export accepts only logical
ids, reinspects them under an output-scoped lock, and renders complete generated
files before replacement. Current-export fingerprints bind explicit withdrawal
acknowledgements to prior canonical definitions. The catalog exposes no resource
definitions, commands, file content, credentials, claims, or cleanup authority.

The Share panel requests that catalog only while its workflow is active,
validates it in `Model.js`, and keeps draft selection and metadata in memory.
`Service.qml` passes only argument-array metadata, ids, and acknowledgement
fingerprints to the CLI. QML never reads the profile, package database, plugin
tree, launchers, theme state, or applied-loadout registry to reconstruct an
inventory. A CLI refusal refreshes the catalog without being presented as an
export success.

`mntg apply` resolves and normalizes the source, plans compatible/shared/conflicting resources, confirms, records desired state and a journal before mutation, and records each outcome. Exact reapply reconciles the same local loadout; changed known-source content requires explicit update. Check is read-only, repair is explicit, and removal withdraws claims using provenance and current evidence. The panel consumes CLI JSON and hands mutations to a terminal.

## External tools

The CLI composes existing Omarchy and Arch tools including Git, `jq`, `rsync`, `pacman`, `yay`, `systemctl --user`, `age`, and the `omarchy` CLI. Tests put doubles for these tools on `PATH`; real-machine and VM validation cover behavior the doubles cannot prove.

## Trust boundaries

- **Vaults and loadouts are untrusted input.** Names, paths, URLs, schema versions, commits, and launcher fields are validated before they reach commands or mutation.
- **AUR packages cross an execution boundary.** PKGBUILDs run on the machine, so their build decision is separate from ordinary restore confirmation.
- **User services cross a persistence boundary.** Enabling a service schedules future execution, so candidates and executable commands are shown before a separate decision.
- **Secrets cross a confidentiality boundary.** Ordinary capture excludes credential paths; the opt-in secrets path encrypts before storage and restores private permissions.
- **The panel crosses a consumer boundary.** It receives JSON or porcelain output from the CLI and must tolerate invalid output without inventing state.
- **The registry crosses a deletion-authority boundary.** It is local but hand-editable, so every mutation validates all identities and relations and reconstructs rather than trusts deletion targets.
- **Remote Git state crosses a network boundary.** Restorable shared code requires safe remotes and recorded commits unless the user explicitly accepts an unpinned head.

## Verification boundary

The automated suite proves command decisions and filesystem effects inside a sandbox. It does not prove real package installation, a service starting at login, a visible theme change, rendered panel behavior, or timing on a clean Omarchy installation. Those boundaries are documented in the [testing strategy](../testing/strategy.md).
