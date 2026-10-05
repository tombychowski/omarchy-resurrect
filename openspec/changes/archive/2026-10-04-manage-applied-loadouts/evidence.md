# Validation evidence

## Real-machine scratch run — 2026-10-04

Environment: Omarchy `4.0.0.alpha`, pacman `7.1.0` / libalpm `16.0.1`.
The run used a `mktemp` home, XDG state/data/config/cache directories, and a
scratch ress registry. It did not read or write the live ress vault. The pacman
step used `--print` only and performed no privileged transaction.

Command:

```bash
tests/manual/loadout-real-scratch.sh
```

Observed results:

- tracked apply created the registry with mode `0600`;
- real pacman refused direct removal of installed `libpng` because it would
  break dependencies, and `pacman -Q libpng` confirmed it remained installed;
- real `omarchy-plugin-remove` disabled an enabled disposable plugin, removed
  its Git checkout, and requested a shell plugin rescan;
- real `omarchy-webapp-remove` removed a disposable launcher and attributable
  icon;
- real `omarchy-theme-remove` removed a disposable user theme; and
- real headless `omarchy-theme-set`, driven by two tracked loadouts, selected
  the later request, fell back to the remaining request on removal, and
  restored the original baseline after the final removal.

The first scratch attempts found two integration defects that the command
doubles had hidden: ress passed an unsupported `--yes` argument to the real
web-app and theme removal commands, and a package-only loadout consumed the
active-theme baseline before any theme claim existed. Both were corrected and
the script passed after focused regression assertions were added.

This is real-command integration evidence, not fresh-machine release evidence.
It does not demonstrate a successful privileged package removal, a visibly
rendered theme transition, or the Loadouts panel in a running desktop shell.
Those remain part of task 8.5 and the clean-Omarchy procedure.

## Final automated validation — 2026-10-04

```text
./tests/run.sh
39 cases passed (842 assertions, 875s)

node tests/model-test.js
all Model.js assertions passed

openspec validate --all --strict
11 passed, 0 failed
```

The corrective mutation run first found that the old
`loadout-new-fabricated-claim-accepted` mutation had become behavior-neutral
after kind-specific claim validation was added. Referential validation was
made explicit, a fabricated-loadout assertion was added, and the mutation was
retargeted to the actual loadout-reference guard. Its exact rerun ended with:

```text
loadout-new-fabricated-claim-accepted caught by 22-loadout-registry
all 1 mutations caught
```

The complete 52-mutation legacy sweep was not repeated in this corrective pass.
Its clean baseline passed, but the expanded suite now takes roughly 4.5 minutes
per mutation, making the serial sweep a multi-hour job. The exact mutation for
the discovered gap and the complete non-mutated suite were both run.

## Clean-Omarchy Proxmox validation — 2026-10-04

Two clean Omarchy `4.0.0.alpha` VMs were provided: a running desktop source and
a headless target. `tests/manual/loadout-vm-preflight.sh` confirmed the target
had no registry, ress plugin, user themes, or fixture packages. The repeatable
transaction driver was `tests/manual/run-vm-loadout-lifecycle.sh` using the two
pinned `vm-loadout-{a,b}.json` fixtures.

The target run observed real Arch package installation and direct removal,
shared package/plugin claims, both loadout removal orders, final cleanup,
modified-plugin refusal and explicit retention, theme precedence and baseline
restoration, external-theme preservation, no orphan sweep, and unrelated data
preservation. Its final audit was zero loadouts/resources/claims, null
operation, all fixture resources absent, Tokyo Night active, and the canary
unchanged. No AUR resource, systemd unit, encrypted secret, or full restore was
part of the run.

On the source, external launcher deletion was detected without implicit repair;
explicit repair reinstalled it. Ordinary apply refused changed known content,
then explicit update reconciled the profile and precedence. The live panel
rendered two healthy rows, keyboard selection, metadata and content detail. Its
Remove action opened `foot` running the exact CLI removal command; cancelling
before confirmation preserved two healthy loadouts and a null operation. The
approved tight crop is `docs/media/loadouts.png`.

The source also supplied the rendered theme boundary. With A effective and B
still tracked, removing A selected Hermarchy before deleting Sunset Drive; the
observer confirmed Hermarchy was visibly applied. Removing B then restored the
recorded Tokyo Night baseline before deleting Hermarchy; the observer confirmed
Tokyo Night was visibly applied. The final source registry also contained zero
loadouts/resources/claims and no operation, while the ress panel plugin itself
remained installed.

The run exposed and fixed three integration defects:

- a lower-precedence theme request was initially reported missing merely
  because another tracked request was effective;
- `omarchy webapp remove` deleted a launcher but returned nonzero after a
  desktop-database refresh, leaving a ghost pending claim; and
- `omarchy plugin remove` could not reach deletion without live shell IPC on a
  headless fresh machine.

Focused assertions now cover standby theme health, post-deletion web-app
reinspection, and headless removal through Omarchy's own plugin remover. The
complete source/target observations and the six original fresh-machine
boundaries are recorded in `docs/testing/fresh-machine-validation.md`.
