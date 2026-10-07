# Restore safety

Restore replays one validated immutable backup onto the current Omarchy
machine. Its safety model is exact-snapshot selection, preview before mutation,
general confirmation, separate higher-power consent, preservation of replaced
files, and commit-bound resumability.

The `resumable-restore`, `non-destructive-defaults`,
`explicit-execution-consent`, `credential-protection`,
`schema-compatibility`, and `untrusted-artifact-reading` OpenSpec capabilities
own the observable guarantees.

## Exact input before mutation

Before category replay, Montage:

1. validates category names and the selected repository;
2. resolves `--backup COMMIT_OR_LABEL`—or the default `HEAD`—to one commit;
3. reconstructs that commit from Git objects in an isolated private tree;
4. validates its vault envelope, repository identity, machine lineage,
   `backup.json`, payload boundaries, and contained controls;
5. checks required local tools and takes the operation lock; and
6. uses only that isolated tree for preview, confirmation, and replay.

A moving branch cannot change the selected content after resolution. A missing
or symlinked control, escaping link, unsupported object mode, wrong repository
kind, changed identity, crossed lineage, or unsupported schema stops before
machine mutation.

## Preview and general confirmation

Dry run and live preview name the vault repository id, exact backup commit,
source machine, creation time, selected categories, and work that may execute
now or persist later. The latter includes AUR packages, Omarchy hooks,
autostart launchers, remote plugin/theme code, and enabled user services.

`--dry-run` uses the same immutable planning input but performs no category
mutation and writes no restore progress. A dry run using `--from` works against
temporary repository storage rather than replacing the configured vault.

A live confirmation repeats the repository and commit identity. `--yes`
answers that general confirmation only; it does not grant AUR, service, or
unpinned-code consent.

## Category selection and order

The restore order is packages, config, plugins, Omarchy state, web apps, then
secrets. `--only LIST` restricts work and `--skip LIST` excludes work. Unknown
names fail rather than silently selecting nothing. Independent later
categories may continue after a recorded category failure when safe.

## Independent consent gates

### AUR packages

AUR entries represent build instructions fetched and executed locally. The
user must choose separately:

- `--aur` authorizes the noninteractive build path;
- `--review-aur` preserves the helper's review questions; and
- `--no-aur` defers builds.

The shipped and user deny lists apply first. General `--yes` cannot answer this
decision.

### User services

Captured enabled-state is evidence, not permission. Montage shows candidate
unit names and executable commands when discoverable. `--enable-units` or
`--no-enable-units` makes the separate choice; `mntg enable-units` can inspect
and enable deferred candidates later.

### Unpinned remote code

Plugins and Git themes normally restore from a safe remote at a recorded
commit. `--allow-unpinned` is an explicit exception, with a separate
first-contact confirmation when branch-head code would be accepted.

## Non-destructive defaults

Restore is additive. It installs absent packages but does not uninstall extras,
and it does not delete unrelated files because they are absent from a backup.
Safe-link copying cannot redirect writes outside intended roots. A replaced
file is retained with `.montage-bak`; newly created files receive no fabricated
backup.

Web apps are rebuilt through validated Omarchy commands rather than installing
captured launchers verbatim. Remote code uses the recorded commit unless the
unpinned exception was granted.

## Checkpoint and resume identity

Live progress is stored in `~/.local/state/montage/restore.state`. The identity
line contains the stable vault repository id and resolved backup commit;
subsequent lines name completed categories. Another repository or commit
starts a new completion set. `--restart` discards the selected backup's saved
progress explicitly.

A category is complete only when it finishes without a recorded failure and
is not deliberately partial. Declined AUR builds and other deferred work stay
available and are reported as left for later. Rerunning the same selection
skips only completed categories.

## Explicit applied-loadout removal

Vault restore remains additive. The separate `mntg loadout remove LOCAL_ID`
workflow may remove a resource only from validated machine-local Montage claim
and cleanup evidence. It previews release, preserve, delete, and
decision-required outcomes; preserves shared, pre-existing, changed,
unverifiable, critical, or dependency-protected resources; and resumes
incomplete cleanup from the applied-loadout registry. Imported Ress claims are
never adopted as Montage cleanup authority.

## Failure and verification semantics

Validation and confirmation failures stop before category replay. During
replay, failures and deferred work remain distinct. Porcelain ends with
`DONE|ok|...` when no category failed and `DONE|partial|...` otherwise.

A completed restore says the chosen workflow finished under its decisions; it
does not claim universal equivalence. `mntg verify --backup COMMIT_OR_LABEL`
independently compares the machine with the same immutable backup and exits
nonzero when restorable state is missing or differs.

See [Back up and restore](../workflows/backup-restore.md) and
[Vault repository and backup format](vault-format.md).
