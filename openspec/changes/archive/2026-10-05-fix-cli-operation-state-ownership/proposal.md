# Proposal

## Why

The operation marker and configuration lock currently do not preserve the ownership they are intended to represent: any CLI process can erase another process's running marker, and a timed-out configuration writer continues without a lock. These races can make the panel report false idle state and can lose concurrent settings changes.

## What Changes

- Make the process that successfully acquires the primary operation lock the only process allowed to create and remove its running marker.
- Keep dry runs serialized without creating a visible running marker.
- Make configuration read-modify-write fail clearly when its dedicated lock cannot be acquired instead of proceeding unlocked.
- Add concurrent-process regression coverage for marker lifetime, dry-run behavior, ordinary read commands, and configuration lock timeout.
- Reconcile panel operation language, CLI architecture, and testing documentation with explicit marker and configuration-lock ownership.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `panel-integration`: require externally running presentation to remain tied to the actual operation-lock owner and require concurrent panel setting writes to remain serialized rather than fall through unlocked.

## Impact

- **CLI runtime:** `lib/ress/core.sh` lock and cleanup ownership, plus callers that inspect the operation-lock flag.
- **Panel semantics:** `Service.qml` continues watching the same marker path, but the marker becomes an accurate lock-owner signal.
- **Contracts and architecture:** `docs/panel/cli-integration.md`, `docs/panel/status-language.md`, and `docs/architecture/cli-modules.md` describe ownership and timeout behavior.
- **Automated evidence:** focused concurrency cases cover unrelated CLI exit, live and dry-run operations, refusal on lock contention, and configuration timeout without writes.
- **Compatibility:** no command, option, state path, or successful-operation output changes; a configuration write that cannot acquire its lock now fails instead of racing.
