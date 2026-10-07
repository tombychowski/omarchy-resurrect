# Status language

Montage keeps backup freshness, repository health, and operation state
independent. A stale backup is not a failed operation; a healthy repository does
not prove an applied loadout is healthy.

## Backup freshness

| Condition | Panel language |
|---|---|
| no successful timestamp | `Never backed up` |
| within `staleHours` | `Backed up <relative time>` with normal treatment |
| older than `staleHours` | the same factual age with stale treatment |

The default threshold is 48 hours. Documentation uses **missing**, **current**,
and **stale**, never “safe.”

## Repository surface

| State | Meaning and current presentation |
|---|---|
| `loading` | `Loading repositories…` or an action-specific loading label |
| `invalid` | CLI data is unavailable or invalid; `Repository information is invalid or unavailable.` |
| `empty` | no configured repositories, or the selected repository has no items |
| `healthy` | `Repository is healthy.` |
| `stale` | remote history is ahead; review before use |
| `divergent` | local and remote histories diverge; `Review divergence in terminal` |
| `attention` | invalid entries, a failed sync observation, or another qualified condition needs review |

These states come from validated repository, content, and sync JSON. They are
not derived from Git files.

## Applied-loadout health

| CLI state | Panel label |
|---|---|
| `healthy` | `Healthy` |
| `pending` | `Pending work` |
| `drifted` | `Needs repair` |
| `conflicting` | `Conflict` |
| `removal-pending` | `Removal pending` |
| malformed or unknown | `Unavailable` |

## Share and history language

- **All shareable resources**, **Selected loadout**, **Empty selection**, and an
  applied loadout are the explicit composer starting choices.
- **No longer available** requires identity-specific acknowledgement before
  omitting a prior selected-loadout resource.
- **Choose at least one resource** explains a disabled empty update.
- **Restore this exact backup** always refers to the displayed full commit.
- **Preview retention** is read-only; **Run retention in terminal** previews
  again and asks before rewriting local history.
- **Preview Ress port** is read-only; **Publish port in terminal** is separate.

## Operation state

`Working…`, current step labels, and numeric progress come from porcelain. A
zero exit with `DONE|ok` permits `Backed up` or `Loadout exported`. Partial or
failed terminal state uses `<action> finished with problems`; a missing message
falls back to the exit code. Deferred work remains distinct from both success
and failure.

Malformed JSON withholds the affected view rather than showing invented empty
or healthy state. A valid backup summary can coexist with an unavailable
repository, composer, or applied-loadout view.

The [CLI protocol](../contracts/cli-protocol.md) defines records and envelopes;
[CLI integration](cli-integration.md) defines their panel use.
