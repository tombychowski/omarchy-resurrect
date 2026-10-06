# Design

## Context

See `proposal.md` for motivation. `bin/ress` installs one EXIT trap for every invocation. `take_lock` currently creates the panel-visible marker, while the unconditional cleanup path removes that marker even for commands that never acquired the lock. The dedicated configuration lock similarly waits but treats timeout as success. The marker path and panel watcher are established external interfaces and remain unchanged.

## Goals / Non-Goals

**Goals:**

- Bind marker creation and removal to the exact process that acquired the primary lock.
- Preserve dry-run serialization without advertising machine mutation.
- Make configuration read-modify-write fail closed on lock timeout.
- Cover real concurrent processes rather than only sequential marker existence.

**Non-Goals:**

- Change lock paths, marker paths, panel polling, or command output on successful operations.
- Introduce a daemon, distributed lock, or persistent operation database.
- Solve stale markers created by an uncatchable power loss beyond overwriting them when a later process successfully acquires the released lock.

## Decisions

### 1. Track operation-lock and marker ownership separately

Replace the loadout-specific lock flag with process-wide operation ownership state. Successful `flock` acquisition records that the process owns the primary lock. A live non-dry-run operation writes a unique marker token and records that token in memory; dry runs record lock ownership but no marker ownership.

Cleanup removes the marker only when this process recorded marker ownership and the current marker still contains its token. Token comparison protects against removing a marker that was replaced after an unusual cleanup race or manual intervention. Using marker existence alone was rejected because it cannot distinguish ownership.

### 2. Keep the existing marker file as the panel interface

`Service.qml` needs only file existence and continues to watch the same location. The marker payload becomes an opaque ownership token; it is not a new consumer protocol. Changing the marker to a directory or adding panel-side lock inspection was rejected because the CLI must remain authoritative and the existing watcher already provides the required presentation signal.

### 3. Fail configuration writes when locking fails

`take_config_lock` returns success only after `flock` succeeds and otherwise terminates through the normal CLI error path before the protected reread. Continuing unlocked is rejected because it recreates the lost-update race the lock exists to prevent. The existing timeout remains bounded so a stuck writer does not hang panel actions indefinitely.

### 4. Test ownership with overlapping processes

Focused tests hold the primary and configuration locks in separate processes, invoke unrelated commands, and inspect marker/config state while the owner is alive. This proves lifetime behavior that a sequential create/exit assertion cannot cover. The tests remain inside the harness sandbox and do not touch the user's live marker or configuration.

## Risks / Trade-offs

- **[Marker token comparison leaves a manually replaced marker behind]** -> Treat a mismatched token as state owned by something else; a later successful lock owner overwrites stale content safely.
- **[Configuration contention becomes a visible failure]** -> Return a precise retryable error and leave the file unchanged; silent racing is not an acceptable fallback.
- **[Renaming the lock flag misses a caller]** -> Search the complete production tree, update module ownership documentation, and retain focused lock plus full-suite evidence.

## Migration Plan

1. Add failing concurrent marker and configuration-lock regression cases.
2. Introduce explicit operation-lock and marker-token ownership in core cleanup.
3. Make configuration lock timeout fail before reread/write.
4. Reconcile panel and architecture documentation and run focused tests, the full suite, mutation evidence for the affected guards, and strict OpenSpec validation.

No persistent migration is required. Rollback restores the prior runtime code; marker and configuration paths and formats are unchanged.
