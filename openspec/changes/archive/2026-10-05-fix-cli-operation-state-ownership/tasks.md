# Tasks

## 1. Operation Marker Ownership

- [x] 1.1 Add an overlapping-process regression case that holds the primary operation lock, runs read-only/help/version commands, and verifies the owner's marker remains until the owner exits; verify the focused case fails against the pre-fix implementation and never touches live user state
- [x] 1.2 Replace the loadout-specific lock flag with explicit process-wide operation-lock ownership and a unique marker token, and verify only the process whose token still matches can remove the marker
- [x] 1.3 Cover dry-run acquisition and cleanup in the focused case, verifying dry runs remain serialized without creating or removing the panel-visible marker
- [x] 1.4 Reconcile marker ownership language in `docs/panel/cli-integration.md`, `docs/panel/status-language.md`, and `docs/architecture/cli-modules.md`, and verify the documented path and panel interpretation match the focused assertions

## 2. Configuration Locking

- [x] 2.1 Add focused concurrent configuration cases that hold the config lock through timeout and overlap two successful writers, verifying timeout leaves the file byte-for-byte unchanged and serialized writers preserve both updates
- [x] 2.2 Make config-lock acquisition fail through the normal CLI error path before protected reread or write when `flock` times out, and verify the focused timeout and concurrent-writer cases pass with a clear retryable error
- [x] 2.3 Document config-lock ownership and timeout behavior in the CLI/panel integration and testing documentation identified by `docs/index.md`, and verify no documentation claims an unlocked fallback

## 3. Integration Evidence

- [x] 3.1 Run all focused marker, dry-run, settings, and panel-protocol cases and verify their assertion totals pass
- [x] 3.2 Run the relevant mutation targets for marker-token comparison and config-lock failure, verifying each mutation is detected by an automated case
- [x] 3.3 Run `./tests/run.sh` and `openspec validate --all --strict`, verifying the full suite and every OpenSpec artifact pass; record any real-machine or fresh-VM-only evidence explicitly rather than claiming sandbox coverage
