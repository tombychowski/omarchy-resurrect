# Proposal

## Why

The recent module split made the 5,000-line CLI navigable, but important runtime dependencies still run opposite the documented layering, unreachable compatibility code remains, and loadout inspection launches many `jq` and package-manager processes per resource. Cleaning these seams now will keep future categories and resource kinds from multiplying coupling and test latency.

## What Changes

- Remove unreachable `cmd_apply_legacy`, unused helpers, and dead locals after proving the public apply and legacy whole-machine share workflows remain covered.
- Move shared package/AUR probing and consent out of vault restore into a neutral machine-operation module.
- Move loadout plan construction into a planning owner and registry outcome transitions into the registry owner so lifecycle/resources no longer call apply-owned internals.
- Centralize configuration keys, defaults, validation metadata, and persistence order without changing accepted settings or serialized config shape.
- Batch per-command package/theme observations, registry indexing, and JSON row assembly to avoid repeated external commands and array-copy transformations.
- Split oversized restore responsibilities by state, preview/consent, and category replay only where ownership becomes clearer; do not merge vault categories with public loadout resources.
- Add static dependency/dead-code evidence, per-case timing, bounded parallel suite execution, ShellCheck/formatting gates where available, and performance fixtures based on command counts rather than fragile wall-clock thresholds.
- Update CLI architecture and testing documentation to match the resulting ownership graph and evidence.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This change preserves commands, options, outputs, exit status, protocols, formats, consent, state paths, and panel behavior; `.openspec.yaml` declares `skip_specs: true`.

## Impact

- **CLI implementation:** `bin/ress` and modules under `lib/ress/`, potentially including new neutral machine-operation, loadout-planning, and checked jq filter files.
- **Automated evidence:** `tests/run.sh`, focused loadout scaling/call-count cases, module-boundary checks, and mutation targets.
- **Architecture and testing docs:** module inventory, allowed dependency direction, shared-state ownership, extension guidance, and suite execution.
- **Dependencies:** no new runtime dependency; Bash, jq, Git, pacman/yay, and Omarchy integrations remain the execution boundary.
- **Observable behavior:** no intended change. Any newly discovered behavioral discrepancy must be moved into a separate behavior-changing OpenSpec change rather than absorbed here.
