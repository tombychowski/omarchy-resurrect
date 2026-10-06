# Tasks

## 1. Baselines And Dead Code

- [x] 1.1 Add focused golden coverage for tracked loadout apply plus legacy whole-machine share/apply compatibility, and record current subprocess counts and per-case duration so subsequent behavior-preserving diffs can be compared
- [x] 1.2 Remove unreachable `cmd_apply_legacy`, unused `json_escape`, and proven unused locals, and verify focused compatibility cases, public/dynamic entrypoint checks, and relevant mutation targets still pass
- [x] 1.3 Add a reviewed dead-code/entrypoint check with explicit allowances for Bash dynamic dispatch, document its limits in `docs/testing/strategy.md`, and verify it flags a deliberately introduced unreachable fixture function

## 2. Acyclic Module Ownership

- [x] 2.1 Extract shared installed-package, repository/AUR probing, AUR consent, and package-install helpers into a neutral machine package module, and verify vault restore and loadout focused cases preserve command order, consent, output, and exit status
- [x] 2.2 Extract definition compatibility and apply/update/repair plan construction into a loadout planning module, and verify golden human, JSON, and porcelain plans remain byte-for-byte equivalent
- [x] 2.3 Move claim/outcome transitions into the registry owner and update lifecycle/resources callers, and verify apply, update, repair, remove, and registry recovery cases preserve stored state and outcomes
- [x] 2.4 Replace core's domain-specific temporary globals with bounded cleanup registration through controlled creation helpers, and verify cleanup accepts only approved parents, distinguishes files/directories, and mutation tests catch removal of its containment guard
- [x] 2.5 Add an allowed module-dependency map plus public/dynamic entrypoint allowlist, update `docs/architecture/cli-modules.md` with the resulting ownership graph and extension rules, and verify the checker rejects representative reverse dependencies

## 3. Central Configuration Schema

- [x] 3.1 Introduce one core-owned schema for persisted keys, defaults, accepted types/choices, and stable serialization order, then route load, set, save, and status conversion through it; verify existing config fixtures and outputs are byte-for-byte unchanged
- [x] 3.2 Add malformed/unknown hand-edited config fixtures and schema-consistency assertions, and verify safe fallback, ignored unknown keys, validation messages, and persisted ordering remain compatible
- [x] 3.3 Reconcile configuration ownership and extension guidance in architecture and panel integration documentation, and verify QML remains a consumer of CLI/config contracts rather than a second schema authority

## 4. Batched Inspection And JSON Assembly

- [x] 4.1 Add representative 10- and 50-resource loadout fixtures that count package inventory, active-theme, registry-index, and jq invocations while comparing human, JSON, porcelain, plan, and check results to current golden output
- [x] 4.2 Build one command-scoped observation snapshot for stable batch facts and retain immediate rereads for mutation-sensitive guards, and verify package/theme observation command counts stay bounded as resource count grows
- [x] 4.3 Build registry indexes once per command and consume them from planning/check/apply paths, and verify duplicate/claim/outcome behavior plus registry recovery output remains unchanged
- [x] 4.4 Replace repeated growing-array jq transformations with newline-delimited records or Bash accumulation followed by one assembly pass, moving only substantial reusable filters into checked `lib/ress/jq/` files; verify jq invocation counts and all golden outputs
- [x] 4.5 Document snapshot lifetime, live-truth boundaries, and performance evidence in architecture/testing docs, and verify tests use deterministic command counts rather than wall-clock pass/fail thresholds

## 5. Restore Ownership Decomposition

- [x] 5.1 Extract restore progress/journal state from category replay where doing so removes a dependency edge, and verify interrupted/resumed restore and status/progress fixtures preserve paths, transitions, and recovery behavior
- [x] 5.2 Extract preview/consent orchestration from category replay where ownership becomes acyclic, and verify preview, refusal, dry-run, and accepted-mutation cases preserve ordering and messages
- [x] 5.3 Split remaining category replay only along clear policy boundaries, keeping private vault representations distinct from public loadout resources; verify capture/restore/verify focused cases and update `docs/architecture/cli-modules.md` for every moved owner

## 6. Faster And Stronger Test Feedback

- [x] 6.1 Add per-case duration reporting to `tests/run.sh` without changing default selection, result order, exit status, or assertion totals, and verify a focused multi-case run reports stable names and totals
- [x] 6.2 Audit and make test fixtures sandbox-relative, add bounded `--jobs` execution with `--jobs 1` compatibility, and verify sequential and parallel full runs report identical cases/assertions with no shared-state failures
- [x] 6.3 Add reproducible ShellCheck and formatting gates where the repository/CI environment can provide them, or record the exact availability limitation in testing documentation; verify the chosen gate runs deterministically in its declared environment
- [x] 6.4 Update `docs/testing/strategy.md` with timing, parallelism, structural checks, mutation sequencing, and sandbox boundaries, and verify it does not present local tool availability or wall time as behavioral proof

## 7. Integration Evidence

- [x] 7.1 Run focused loadout, registry, configuration, restore, module-boundary, dead-code, cleanup, and performance call-count cases, verifying all behavioral goldens and structural assertions pass
- [x] 7.2 Run the full suite with `--jobs 1` and the selected bounded parallel job count, verifying identical case/assertion totals and retaining both duration summaries as implementation evidence
- [x] 7.3 Run the repository mutation sweep and `openspec validate --all --strict`, verifying all applicable mutations are killed and every OpenSpec artifact passes; record any real-machine or fresh-VM-only validation instead of claiming it ran in the sandbox

## Implementation evidence

- Focused compatibility, ownership, configuration, cleanup, restore, scale, and structural cases pass.
- Full sequential run: 47 cases, 1,137 assertions, 382 seconds.
- Full bounded-parallel run (`--jobs 4`): 47 cases, 1,137 assertions, 221 seconds.
- Mutation sweep: all 65 mutations caught; none survived or were skipped.
- `openspec validate --all --strict`: 15 items passed, 0 failed.
- ShellCheck, shfmt, and bashtate were unavailable in the repository environment; `bash -n`, the checked dependency/entrypoint structure gate, focused/full cases, and mutation testing supplied deterministic local evidence.
- Real package/AUR transactions, rendered desktop behavior, unit startup, and fresh-machine timing remain real-machine/fresh-VM validation boundaries documented in `docs/testing/strategy.md`.
