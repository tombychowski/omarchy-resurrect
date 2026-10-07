# Panel CLI integration

`Panel.qml`, `Service.qml`, and `Model.js` are consumers of the one authoritative
CLI at `bin/mntg`. Process commands are argument arrays, never shell strings.

## JSON query map

| Panel state | CLI query | Model validator |
|---|---|---|
| summary | `mntg status --json` | status object parsing |
| configured repositories | `mntg repository list --json` | `parseRepositoryList` |
| selected repository loadouts | `mntg repository loadouts NAME --json` | `parseLoadoutCatalog` |
| selected vault history | `mntg --vault PATH backup list --json` | `parseBackupList` |
| synchronization preview | `mntg repository sync NAME --json` | `parseSyncResult` |
| selected-loadout composer | `mntg share catalog --repository NAME --loadout ID --json` | `parseShareCatalog` |
| applied loadouts | `mntg loadout list --json --contents` | `parseLoadoutList` |
| live applied health | `mntg loadout check --json` | `parseLoadoutCheck` |
| retention preview | `mntg --vault PATH --dry-run backup retain --keep COUNT --json` | `parseRetentionResult` |
| Artifact conversion preview (currently Ress v1) | `mntg port ress plan SOURCE --destination PATH --json` | `parsePortReport` |

Each accepted result has `schemaVersion: 1` and the expected `kind`. Port
reports additionally carry a bounded `format`; the model validates the shared
envelope without interpreting the foreign artifact. Validation
failure publishes unavailable state. The panel never calls Git or reads
repository envelopes, profile leaves, backup manifests, or history directly.

The applied-loadout inventory and check are validated independently and merged
only by stable local identity. A non-zero health-check exit may still carry a
valid JSON result describing drift.

## In-panel operations

Backup and selective share use `mntg --porcelain`. `Model.parseRecord` accepts
the base records plus versioned `SYNC` and `PORT` records. Unknown records and
human prose are ignored. `STEP`, `PROGRESS`, `LOG`, and `DONE` drive only
transient presentation; process exit and stderr remain meaningful.

Selective share sends the configured repository name, stable loadout id, user
metadata, sorted resource ids, and exact acknowledgement fingerprints. The CLI
reinspects machine state and publishes the repository update atomically.

## Interactive terminal handoff

The following actions use `omarchy-launch-terminal` with the resolved `mntg`
path:

- exact restore: `mntg --vault PATH restore --backup COMMIT`;
- repository apply preview/apply: `mntg apply PATH --loadout ID [--dry-run]`;
- applied-loadout update, repair, and removal;
- retention: `mntg --vault PATH backup retain --keep COUNT`;
- synchronization continuation or divergent-history review; and
- Ress import publication after a successful port preview.

QML does not elevate privileges, accept loss, answer AUR/service prompts, or
infer completion from closing the panel.

## Settings dispatch

Capture and consent settings call `mntg set KEY=VALUE`. Repository settings call
`mntg repository configure NAME PATH TYPE [--remote URL] --replace`. The CLI
owns validation, bounded locks, re-read-under-lock, identity replacement rules,
and persistence. QML strips URL userinfo before dispatch and refuses Ress
locations as live Montage repositories. See [Panel settings](settings.md).

## Scheduling and watched state

Only the headless service schedules backups. It uses the later of the last
successful backup and last attempt to avoid a rapid retry loop. Small
Montage-owned config and operation-stamp files are watched for scheduling and
freshness; repository, history, artifact, and machine-resource interpretation
always goes through CLI output.

## Verification boundary

`tests/model-test.js` verifies parsers and panel state vocabulary.
`tests/cases/16-qml.sh` runs those tests, QML lint when available, verifies every
`engine.*` member, checks the CLI routes, and rejects old command paths, direct
Git invocation, and repository-artifact parsing. Rendered layout, focus, real
terminal launch, and shell integration require clean-Omarchy evidence described
in [Keyboard workflow](keyboard-workflow.md).
