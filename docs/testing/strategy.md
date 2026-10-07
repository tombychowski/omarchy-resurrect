# Testing strategy

Montage uses four evidence layers. A claim belongs to the lowest layer that can
actually prove it; simulated success is not promoted to real-machine evidence.

## 1. Sandboxed automated suite

```bash
./tests/run.sh
./tests/run.sh repository
./tests/run.sh --jobs 4
```

Every case gets a throwaway home and test doubles for package, privilege,
service, Git/network, and Omarchy boundaries. Before cases run, the harness
syntax-checks `bin/mntg` and every `lib/montage/**/*.sh` module. The suite proves
validation order, path containment, credential omission, locking, atomic
publication, rollback/recovery, JSON and porcelain contracts, stable identity,
repository history behavior, no-op behavior, and exact external command
arguments without changing the developer's machine.

Important focused groups include:

- repository envelopes, registry serialization, transactions, loadout
  libraries, backup history, retention, and sync (`48`–`58`);
- frozen Ress v1 fixtures, inspection, current/history import, export, and loss
  safety (`59`–`65`);
- final command routing and aliases (`66`);
- format-neutral port dispatch, shared report identity, unsupported-format and
  unsupported-callback refusal, one literal callback matrix, adapter isolation,
  forbidden lifecycle calls in adapters, and a shared-engine-versus-adapter
  size guard (`67`);
- QML/Model consumer boundaries (`16`); and
- active source, documentation, manifest, and ownership structure (`47`).

Network authentication, real package transactions, GitHub visibility, rendered
QML, and a clean machine are outside this layer.

## 2. Mutation and structural evidence

```bash
./tests/mutate.sh
./tests/check-structure.sh .
openspec validate --all --strict
```

Mutation testing starts from a clean full-suite baseline and runs one mapped
detector for each intentional behavior break. A surviving mutation means the
suite does not prove the behavior it appears to cover.

The structure check verifies module reachability and dependency direction,
authoritative entrypoints, native naming, documentation links, consumer
boundaries, and that port adapters do not own Git traversal, native repository
transactions, staging, confirmation, publication, or result projection.
The port cases also prove that recognized manifest-only inputs cannot acquire
an executable mutation plan and that JSON decision refusals stay inside one
parseable `montage-port-report`.
OpenSpec validation proves artifact structure and cross-reference integrity; it
does not prove runtime behavior.

## 3. Real tools on disposable paths

Use a real Omarchy installation, disposable native repositories, a temporary
home, and private or local remotes. Never use a valued vault or loadout library.

This layer validates:

- real Git commits, first-parent history, labels, fast-forward fetch/pull/push,
  and divergence classification;
- Git credential helper or SSH-agent authentication without URL userinfo;
- private GitHub visibility checks for vaults;
- real `rsync`, `age`, package query, and Omarchy inspection behavior;
- source/destination byte preservation across Ress ports; and
- plugin manifest validation and update/remove behavior on a disposable copy.

Record commands, versions, repository visibility, expected observation, actual
observation, and cleanup. A failed or skipped observation remains open evidence.

## 4. Clean Omarchy machine or VM

The [fresh-machine checklist](fresh-machine-validation.md) is required for:

- side-by-side Ress and Montage installation and independent removal;
- `mntg`, Ress `ress`, and ImageMagick `montage` command coexistence;
- rendered four-tab panel layout, scrolling, pointer use, and keyboard focus;
- actual native/AUR installation and consent;
- service startup and visible theme effects;
- real private GitHub synchronization and divergent-history presentation;
- exact historical restore from a selected full commit; and
- end-to-end Ress import/export acceptance on disposable copies.

QML lint proves parsing and type resolution, not drawing. Command doubles prove
requested mutations, not that pacman, yay, systemd, GitHub, or Omarchy performed
their real side effects.

## Evidence recording rules

- Never convert an unexecuted checklist into a pass statement.
- Name the exact commit, environment, date, and tool versions.
- Separate automated, disposable-real-tool, clean-machine, and screenshot
  evidence.
- Preserve historical logs as historical; do not present Ress-era evidence as
  current Montage release evidence.
- A screenshot supports layout and wording only. Pair it with CLI/test evidence
  for state semantics.
- Before release, run the full suite and strict OpenSpec validation after the
  last code or documentation change.
