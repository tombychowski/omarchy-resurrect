# Testing strategy

Montage separates automated, disposable-real-tool, rendered, and clean-machine
evidence. A simulated success is never promoted to another layer.

## Automated sandbox

```bash
./tests/run.sh
./tests/check-structure.sh .
./tests/mutate.sh
openspec validate --all --strict
```

Every shell case receives a temporary home and controlled doubles for package,
privilege, Git/network, Omarchy, and desktop-tool boundaries. The suite proves:

- exact command routing and refusal of removed commands;
- portable profile, applied registry, and library schema validation;
- additive planning, provenance, claims, safe cleanup, AUR consent, and lifecycle recovery;
- credential-free URLs, contained regular files, symlink safety, and bounded launcher parsing;
- repository locking, atomic publication, recovery, exact history reads, migration, and synchronization decisions;
- focused Ress v1 inspection/import, loss decisions, source preservation, and one-item publication;
- status precedence, simultaneous causes, malformed-state handling, explicit update evidence, and non-mutation;
- JSON/porcelain validity and strict QML/model consumer parsing; and
- module reachability, dependency direction, documentation links, and mutation detectors.

Command doubles prove exact intent and ordering, not real tool effects.

## Disposable real tools

Use an expendable home, local repositories, and disposable remote host. Record
date, commit, OS/Omarchy and tool versions, exact command, expected and actual
observation, and cleanup. This layer covers:

- real Git commits, fetch refs, fast-forward pull, ordinary push, divergence, credential helpers, and SSH agents;
- real package/AUR transactions and interactive review;
- actual Omarchy plugin, web-app, and theme effects;
- installed configured-registry migration using a copy with inert legacy entries;
- Ress/Montage side-by-side isolation and source/destination byte checks; and
- plugin install, update, link ownership, and removal on disposable paths.

Never use a valued library or existing configuration as a fixture.

## Rendered panel and clean Omarchy

QML lint proves syntax and type resolution, not layout. A clean installation or
VM must cover the three panel surfaces, scrolling, pointer and keyboard parity,
focus return, all attention states, active animation, terminal handoffs, real
package effects, visible theme effects, remote authentication, independent Ress
coexistence, install/update/remove, and absence of obsolete controls.

See [fresh-machine validation](fresh-machine-validation.md).

## Recording rules

Audit correction cases additionally exercise failed/partial package inventory,
established and interim publication journals at every phase, symlinked
destination ancestors and source overlap, unchanged-content provenance previews,
interrupted-operation previews, and migration reporting across CLI entrypoints.
The producer/consumer case runs real CLI JSON through Model and the actual
Service completion handlers in both event orders; it also executes text-field
focus and preset action dispatch. Those JavaScript checks do not prove rendered
focus, pointer interaction, or layout. New audit mutation detectors independently
disable these guards to establish that the focused cases fail.

- An unexecuted check is deferred, never passed.
- Preserve historical logs as historical; do not cite them as current release evidence.
- Screenshots prove layout and wording only; pair them with CLI evidence for semantics.
- Run all automated gates after the last code or documentation edit.
- A failure remains visible until rerun in the same evidence class.

## Loadout-only transition matrix

| Boundary | Automated evidence | Outside sandbox |
|---|---|---|
| Removed product surface | routing, source list, dependency map, searches | installed upgrade/removal |
| Preservation and consent | apply/check/repair/update/remove, claims, AUR cases and mutations | real pacman/yay review |
| Configured-registry migration | valid/invalid matrices, concurrency, interruption, exact rollback, sentinel paths | copied installed configuration |
| Library synchronization | local bare repositories and command doubles | real credentials/remote host |
| Ress v1 import | frozen fixtures, hostile input, decision parity, atomic publication, byte checks | installed Ress and Montage |
| Status/panel | precedence, no-write checks, parsers, QML lint | rendered and keyboard evidence |
| Integration effects | exact pins, fake Omarchy effects, cleanup guards | real plugin/theme/web-app effects |
| Release | manifest, docs links, current-surface inventory | fresh install/update/remove |
