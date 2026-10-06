# Tasks

## 1. Make the evidence module-aware

- [x] 1.1 Update `tests/run.sh` to discover and `bash -n` check `bin/ress` plus every tracked production file under `lib/ress/`, failing with the exact file name, and verify the runner still reaches and passes `./tests/run.sh empty` before any modules exist.
- [x] 1.2 Change `tests/mutate.sh` so each mutation names an explicit repository-relative production file, the mutated tree syntax-checks the complete production Bash inventory, and missing anchors or invalid targets remain hard failures; verify with `./tests/run.sh mutation-baseline` and at least one focused mutation.
- [x] 1.3 Update `docs/testing/strategy.md` with the production Bash inventory, syntax gate, explicit mutation ownership, and the unchanged real-machine/VM boundary; verify every described command and path exists.

## 2. Establish bootstrap and shared-module boundaries

- [x] 2.1 Add the literal, fail-closed module loader to `bin/ress`, extract shared declarations/config/output/locking/cleanup helpers into `lib/ress/core.sh`, keep trap installation and argument dispatch in the entrypoint, and verify `./tests/run.sh settings`, `./tests/run.sh porcelain`, and direct `bin/ress --version` pass without source-time stdout.
- [x] 2.2 Extract shared validation, sanitization, source-normalization, pinned-transport, and web-app parsing helpers into `lib/ress/safety.sh`, and vault selection/Git/manifest primitives into `lib/ress/vault/common.sh`; verify `./tests/run.sh hostile-vault`, `./tests/run.sh ssh-source`, `./tests/run.sh webapp-launchers`, and `./tests/run.sh vault-format` pass.
- [x] 2.3 Add focused coverage for direct, symlinked, relocated, and missing-module invocation, including clean JSON/porcelain stdout and pre-mutation failure, and verify the new case passes independently.
- [x] 2.4 Create `docs/architecture/cli-modules.md` with the startup sequence, dependency diagram, complete target file map, source-time rules, state ownership, and extension guidance, link it from `docs/index.md`, and verify all documented module paths and cross-references resolve.

## 3. Extract the vault domain

- [x] 3.1 Move capture, scan-for-backup, manifest-writing, backup, and push functions unchanged into `lib/ress/vault/backup.sh`, add its ownership/dependency/global-state header, update affected mutation targets, and verify `./tests/run.sh backup`, `./tests/run.sh secret-scan`, `./tests/run.sh autostart`, and `./tests/run.sh vault-format` pass.
- [x] 3.2 Move restore progress, preview, AUR and unit consent, category replay, and restore orchestration unchanged into `lib/ress/vault/restore.sh`, add its module header, update affected mutation targets, and verify `./tests/run.sh dry-run`, `./tests/run.sh aur`, `./tests/run.sh units`, `./tests/run.sh first-contact`, and `./tests/run.sh porcelain` pass.
- [x] 3.3 Move verification, explicit scanning, and deferred unit enablement into `lib/ress/vault/verify.sh`; move status, init, settings, secrets configuration, link, doctor, and diff into `lib/ress/vault/commands.sh`; add module headers, update affected mutation targets, and verify `./tests/run.sh verify`, `./tests/run.sh status-config`, `./tests/run.sh secrets`, and `./tests/run.sh empty` pass.
- [x] 3.4 Reconcile the implemented vault module ownership and dependency rows in `docs/architecture/cli-modules.md`, and verify each documented command owner matches the dispatcher and source file.

## 4. Extract the loadout domain

- [x] 4.1 Move registry schema validation, load/save/revision handling, and operation-journal primitives into `lib/ress/loadout/registry.sh`; move profile fetch/normalization/digest/identity/resource conversion into `lib/ress/loadout/profile.sh`; add module headers, update affected mutation targets, and verify `./tests/run.sh loadout-registry`, `./tests/run.sh loadout-lock`, `./tests/run.sh loadout-identity`, and `./tests/run.sh loadout-resources` pass.
- [x] 4.2 Move live inspection and guarded resource install/remove/theme operations into `lib/ress/loadout/resources.sh`; move share discovery/catalog/render/export into `lib/ress/loadout/share.sh`; add module headers, update affected mutation targets, and verify `./tests/run.sh share-compose`, `./tests/run.sh plugin-remotes`, and `./tests/run.sh loadout-check` pass.
- [x] 4.3 Move loadout/resource query, recovery, repair, update, and removal orchestration into `lib/ress/loadout/lifecycle.sh`; move legacy compatibility, planning, claim registration/outcomes, and apply orchestration into `lib/ress/loadout/apply.sh`; add module headers, update affected mutation targets, and verify `./tests/run.sh tracked-apply`, `./tests/run.sh loadout-repair`, `./tests/run.sh loadout-remove`, `./tests/run.sh loadout-update`, and `./tests/run.sh loadout-roundtrip` pass.
- [x] 4.4 Reconcile the implemented loadout module rows and add-command/add-vault-category/add-loadout-resource walkthroughs in `docs/architecture/cli-modules.md`; update `docs/architecture/system-overview.md`, `README.md`, and `AGENTS.md` to describe `bin/ress` plus `lib/ress/` as one authoritative CLI; verify the documents retain the CLI/panel authority boundary and do not claim a behavior or contract change.

## 5. Prove behavior-preserving integration

- [x] 5.1 Audit `bin/ress` so it contains only bootstrap, literal loading, trap installation, usage, global parsing, and dispatch; audit modules for forbidden source-time work and module-to-module `source` calls; verify `bash -n` succeeds for the full production Bash inventory and `git diff --check` is clean.
- [x] 5.2 Run the complete mutation sweep with `./tests/mutate.sh` and verify every mutation is caught with none skipped or surviving after target relocation.
- [x] 5.3 Run `./tests/run.sh` and `openspec validate --all --strict`, record any environment-only limitation if a gate cannot run, and confirm no new real-machine or fresh-VM validation is required because external behavior and state formats are unchanged.
