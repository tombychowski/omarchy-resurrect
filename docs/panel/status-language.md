# Status language

ress presents two independent kinds of state:

- **freshness** describes the age or absence of the last successful backup; and
- **operation state** describes work happening now or the result of the most recent command.

These must not be collapsed. A stale backup is not a failed backup operation, and a current backup does not prove a restore or share command succeeded.

## Freshness

| CLI/QML condition | Meaning | Current presentation |
|---|---|---|
| no successful backup timestamp | There is nothing known to restore from | Hero: `Never backed up`; bar icon uses the missing/urgent treatment |
| age within `staleHours` | The last successful backup is current under the configured threshold | Hero: `Backed up <relative time>`; normal icon |
| age greater than `staleHours` | A backup exists but is older than the chosen threshold | Same factual age text; dimmer icon |

Use **missing**, **current**, and **stale** when discussing these states in documentation. Do not call stale data failed, broken, or unavailable.

The default threshold is 48 hours and the manifest permits a panel setting from 1 to 720 hours. `Model.freshness` owns the three-state calculation.

## Operation states

| State | Meaning | User language |
|---|---|---|
| idle | No panel-owned or external ress operation is active | Show the freshness summary and available actions; do not add a generic “ready” badge |
| starting/running | The CLI process is active; a step may or may not have a numeric total | `Working…`, the current CLI step, `Backing up…`, or `Exporting…`; show determinate progress only for a valid `PROGRESS` total |
| external running | Another ress process owns the operation lock, commonly a scheduled backup | Use the busy presentation without claiming which step is active |
| previewing | Restore or apply is describing planned actions in the terminal and has not crossed confirmation | CLI headings such as `This will install` or the restore preview; the panel only labels the action `Preview what it installs` |
| complete | The process exits zero with terminal state `ok` | `Backed up` or `Loadout exported` for in-panel actions; human CLI completion text in the terminal |
| partial | Restore reached its terminal report with failed category steps | `<action> finished with problems`; the terminal names failures and tells the user a rerun continues remaining work |
| failed | The command stops or exits non-zero without a successful/partial conclusion | Show the CLI/worker error; if none exists, `exited with code <n>` |
| deferred | The user declined gated work or policy skipped it without making the whole command a failure | CLI: `Left for later`; keep it distinct from both failure and completion |
| resumable | Completed categories are checkpointed and unfinished/failed/deferred work remains for the same snapshot | CLI: `Rerun the same command to pick up where it stopped` or a focused follow-up such as `ress restore --only packages --aur` |

## Applied-loadout health

| State | Panel language | Meaning |
|---|---|---|
| `healthy` | `Healthy` | All recorded claims are satisfied; live confirmation still comes from check |
| `pending` | `Pending work` | Installation or consent remains incomplete |
| `drifted` | `Needs repair` | A check found desired state missing or changed |
| `conflicting` | `Conflict` | The same logical identity has incompatible represented content |
| `removal-pending` | `Removal pending` | Some claim cleanup or explicit decision remains |
| unknown/malformed | `Unavailable` | The consumer cannot safely interpret the state |

The Loadouts summary merges stored inventory with a live, read-only check and names how many are tracked and how many currently need attention. A malformed or unmatched result is **unavailable**, never zero. Resource detail uses missing/pending as attention, modified/conflicting/failed as warning, protected/present as healthy, and unverifiable/uncertain as unknown. Check and repair remain distinct: panel refresh never mutates the machine.

## Protocol mapping

The panel consumes the following porcelain states:

- `STEP|...|start|...` — running step;
- `STEP|...|ok|...` — completed step;
- `STEP|...|skip|...` — skipped or deferred step; the message carries the reason;
- `STEP|...|warn|...` — qualified result that did not by itself terminate the operation;
- `STEP|...|fail|...` — failed step and visible error;
- `DONE|ok|...` — complete operation;
- `DONE|partial|...` — operation finished with problems; and
- `DONE|fail|...` — terminal failure.

`LOG|left for later: ...` preserves deferred work for consumers. Message prose is displayed, not parsed to derive a new machine state.

## Status unavailability

If `ress status --json` cannot be parsed, `Service.qml` sets its accepted status object to `null`. Status-dependent summaries are withheld. The panel does not inspect the vault to fill the gap and does not show zero counts as though they came from the CLI.

The same rule applies independently to loadout-list JSON. A valid backup status can coexist with unavailable loadout state and vice versa.

This is a refusal to fabricate state, not a claim that the vault is empty. Operation stderr and exit failures continue to use the failure language above.

## Wording rules

- State what is known: `Backed up 4h ago`, not `Safe`.
- State what is happening: `Backing up…`, not `Almost done`, unless the CLI provides progress.
- Name the consequence of a policy: `asks first`, `builds without asking`, `never builds them`.
- Name deferred work as remaining work, not a warning badge or success.
- Preserve the CLI's distinction between a refused non-restorable item and a missing restorable item.
- Keep a path to the corrective command in terminal output when the next action is known.

The [CLI protocol](../contracts/cli-protocol.md) defines the underlying records; [CLI integration](cli-integration.md) defines how the panel obtains them.
