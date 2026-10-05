# Restore safety

Restore replays a validated vault onto the current Omarchy machine. Its safety model is preview first, mutate only after confirmation, separate consent for higher-power actions, preserve replaced files, and record enough progress to resume.

The `resumable-restore`, `non-destructive-defaults`, `explicit-execution-consent`, `credential-protection`, and `schema-compatibility` OpenSpec capabilities own the observable guarantees.

## Validation before mutation

Before replaying categories, restore:

1. validates `--only` and `--skip` category names;
2. normalizes a supplied source and handles replacement of an existing local vault as an explicit decision;
3. checks required local tools;
4. obtains the operation lock;
5. locates and parses the canonical or supported legacy manifest; and
6. validates the schema as a plain supported integer.

A typo in a category, an invalid schema, or a missing dependency stops the operation instead of silently selecting no work or failing after partial mutation.

## Preview before a live restore

A live restore reports the source machine and snapshot, then describes planned work before general confirmation. The preview includes selected categories and calls out content that may execute now or persist later, including AUR packages, Omarchy hooks, autostart launchers, and enabled user services with their executable commands when discoverable.

The general confirmation covers writing configuration and performing ordinary selected actions. `--yes` can supply that confirmation but does not grant the independent AUR or service decisions below.

`--dry-run` uses the same planning paths but performs no category mutation and writes no restore progress. When used with `--from`, it clones into a temporary directory so preview does not replace or repoint the configured vault.

## Category selection

The restore order is:

1. packages
2. config
3. plugins
4. Omarchy state
5. web apps
6. secrets

`--only LIST` restricts work to named categories; `--skip LIST` excludes named categories. Lists are comma- or space-separated as accepted by the CLI. Unknown names fail before the category loop.

The order reflects dependencies and recovery value, but a category failure does not automatically erase progress already completed by other categories.

## Independent consent gates

### AUR packages

AUR entries represent PKGBUILDs fetched and executed on the local machine. The user must choose to build, review, or decline them independently of file overwrite confirmation.

- `--aur` authorizes the noninteractive build mode.
- `--review-aur` runs the helper without flags that answer package review questions.
- `--no-aur` declines this run.
- With no explicit choice, the configured `AUR` policy is used; the default is `ask`.

The shipped and user deny lists are applied before the choice. Declined packages are left pending rather than marked complete.

### User services

Enabled systemd user services arrange for code to run in later sessions. Restore writes captured unit files as configuration, but enabling candidates is a separate choice that shows service names and their executable commands when available.

- `--enable-units` authorizes enablement for the run.
- `--no-enable-units` leaves them disabled.
- With no explicit choice, the configured `ENABLE_UNITS` policy is used; the default is `ask`.

`ress enable-units` can inspect and enable deferred candidates later. General `--yes` does not imply either AUR or service consent.

### Unpinned remote code

Plugins and Git themes normally restore only from a safe remote at a recorded commit. `--allow-unpinned` explicitly permits a branch head. On first contact with a vault, ress explains that consequence and obtains a separate confirmation before using the exception.

## Non-destructive defaults

Restore is additive:

- it installs only packages absent from the current package database;
- it does not uninstall packages absent from the vault;
- it does not delete unrelated files merely because they are absent from captured directories;
- it copies with safe-link handling so crafted links cannot redirect writes outside the intended boundary; and
- it retains an existing replaced file using the `.ress-bak` suffix.

New files do not receive fabricated backups. The supported legacy `.resurrect-bak` suffix remains excluded from later capture, but new replacements use `.ress-bak`.

Web apps are rebuilt through the Omarchy CLI from validated fields rather than installing a captured launcher verbatim. Shared code is checked out at its recorded commit by default.

## Checkpointing and resume

Live restore progress is stored in `~/.local/state/ress/restore.state`. The first line identifies the local vault path and manifest creation timestamp; subsequent lines name completed categories.

Progress belongs to one snapshot of one vault. Selecting a different vault or a newer snapshot resets the completion set, preventing stale progress from skipping new work. `--restart` explicitly discards the saved progress for the selected snapshot.

A category is marked complete only when it finishes without a recorded failure and is not deliberately partial. On rerun, completed categories are skipped and remaining work is offered again.

Declined AUR builds and other intentionally deferred category work are reported as “Left for later.” They are not failures, but they are not written as complete.

## Explicit applied-loadout removal

`ress loadout remove ID` is the narrow exception to additive apply and restore. It previews every claim as delete, release-only, retain, already-absent, protected, or decision-required and requires confirmation. A resource is automatically deleted only when all of these remain true at the final inspection:

- ress observed it absent before the first claim and recorded cleanup authority;
- the selected loadout owns the last claim;
- current kind-specific evidence still matches the represented resource; and
- no critical-resource or dependency safeguard refuses removal.

Shared and pre-existing resources only lose the selected claim. Already missing resources are released without reinstallation. Changed or unverifiable resources are preserved until an explicit `--keep-modified` or `--remove-modified` decision; keeping relinquishes cleanup authority and leaves unmanaged machine state. Application data and unrelated configuration are never inferred from a resource claim.

Package cleanup passes only validated direct targets to `pacman -R`. It does not request cascade, recursive dependency cleanup, `--nodeps`, or orphan deletion. Dependency refusal leaves the claim and loadout removal-pending. Any reported orphans are follow-up information only. Critical ress, privilege, package-management, and supported Omarchy runtime packages are protected even if registry provenance is forged.

Plugin, web-app, and installed-theme cleanup is delegated to the corresponding Omarchy command after reinspection. If both IPC and the Omarchy shell process are absent, plugin removal reruns that same Omarchy remover with narrowly scoped no-live-shell responses for its enabled-state query and rescan; Omarchy still owns validation and deletion. An unresponsive live shell fails closed. A delegated nonzero status is accepted only when reinspection proves the intended resource is absent, since a later cache refresh can fail after successful deletion. Modified repositories, launchers, symlinks, mismatched remotes/commits, and ambiguous evidence fail closed. Active-theme intent is resolved before theme content: the newest remaining usable request wins, the baseline is restored after the final request, and an external theme selection is preserved.

Removal records each released claim immediately. Failures remain `removal-pending`; rerunning resumes unresolved work. The loadout record disappears only after every claim/effect is terminal. An interrupted action with ambiguous post-crash evidence becomes `uncertain`, not owned or safely deleted.

## Failure semantics

Validation and confirmation errors stop before the category loop. During replay, category-level failures are collected so independent later work can continue when safe. The final human report distinguishes:

- successful completion;
- completion with problems, including the failed steps; and
- deferred work left for a later decision.

The porcelain terminal record is `DONE|ok|...` for a run without recorded category failures and `DONE|partial|...` when failures occurred. The command exits non-zero for the latter. A rerun against the same snapshot skips only completed categories.

## Verification is separate

A successful restore means the attempted workflow completed under its decisions; it is not a universal claim that the machine matches every restorable item. Run `ress verify` afterward to compare the current machine with the vault. Deferred AUR packages or services can therefore produce a successful restore with an expected verification mismatch until the user completes them.

See [Back up and restore](../workflows/backup-restore.md) for commands and [Vault format](vault-format.md) for the input contract.
