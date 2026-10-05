# Fresh-machine validation

`ress diff --stock` already gives a measured number without any of this. Do the
full run when you want proof, and the recording: an actual fresh Omarchy
becoming your machine, on the clock.

This is the manual/VM layer of the [testing strategy](strategy.md). It verifies
real package installation, absence on a genuinely clean machine, rendered panel
behavior, service startup, visible theme application, and timing—claims the
test doubles and static QML checks cannot prove.

## 1. Decide how the vault reaches the new machine

The new machine has to be able to read your vault. Two ways, and for a test the
first is much less work.

**A — copy the folder (simplest).** The vault is self-contained at
`~/.local/share/ress/vault`. Drop it on a VMware shared folder, a USB image, or
`scp` it over. No remote, no repo, no auth.

```bash
ress backup                                    # make sure it is current
cp -a ~/.local/share/ress/vault /path/to/shared/ress-vault
```

**B — a private git repo (what you'd really use).** Also proves the clone path.

```bash
gh auth setup-git                              # lets git push over https
gh repo create btsouth/omarchy-vault --private
ress set REMOTE=https://github.com/btsouth/omarchy-vault.git
ress backup --push
```

Keep it **private**: the vault holds your dotfiles. Credentials are excluded
from every capture — keys, tokens, `hosts.yml`, `.netrc`, `known_hosts` — but
your Hyprland, Neovim and shell config are in there, and that is yours.

On the new machine a private repo needs credentials before it can be cloned, so
either run `gh auth login` there first, or use method A for the test.

## 2. Get a fresh machine without losing work

Everything here lives in git and is pushed, so reverting a VM cannot lose the
project — at worst it ends a running terminal session.

**Linked clone (safest).** VMware: power off, *VM ▸ Manage ▸ Clone*, base it on
a clean Omarchy snapshot, choose **linked clone** — fast, small on disk. Boot the
clone, test there, delete it. Your working VM is never touched, so nothing
running inside it is interrupted.

**Snapshot forward and back.** Snapshot the current VM as `work`, revert to a
clean Omarchy snapshot, test, then revert to `work`. Costs no disk; costs you the
open session.

**A second VM from the ISO.** Slowest and most honest, because it includes the
Omarchy install itself — the true bare-metal-to-desktop number.

## 3. Run it

On the fresh machine, from a terminal. Two commands, no pipe into a shell:

```bash
omarchy plugin add https://github.com/btsouth/omarchy-resurrect --yes

time ~/.config/omarchy/plugins/tsouth89.resurrect/bin/ress restore \
  --vault /path/to/shared/ress-vault --yes --aur --enable-units
```

With a git remote instead, swap the second line for:

```bash
time ~/.config/omarchy/plugins/tsouth89.resurrect/bin/ress restore \
  --from https://github.com/btsouth/omarchy-vault --yes --aur --enable-units
```

It will ask for your password once, for `pacman`.

`--yes` answers ress's own question about overwriting your home directory. It
deliberately does not answer the other two — building AUR packages and enabling
systemd user services — so an unattended run needs `--aur --enable-units` as
well. **For a recorded demo, leave them off and answer the prompts on camera**:
the questions are the point, and watching one get asked is more convincing than
a paragraph claiming it would have been.

ress prints its own elapsed time at the end; `time` brackets everything
including the download.

If the AUR is slow or something times out, **run it again** — the restore is
resumable and picks up at the step it stopped on. A rerun that completes is a
better demo than a run that never stumbles.

## 4. Check it actually worked

`ress` is not on PATH until you link it, so either run `ress link` first or use
the full path below.

```bash
~/.config/omarchy/plugins/tsouth89.resurrect/bin/ress link
ress verify                       # the whole check, in one line, exit 0 if it matches
```

`ress verify` compares this machine against the vault category by category and
exits non-zero if anything is missing — which is the claim being demonstrated,
stated by the tool rather than by you. The longer form, if you want it on screen:

```bash
ress status                       # counts should match the source machine
ress diff --stock                 # how far this machine was from a fresh install
pacman -Qq | wc -l                # package count in the same range
ls ~/.local/share/applications/   # your web apps
omarchy theme list                # your themes
```

Then look at the desktop: same theme, same bar layout, same wallpaper, your web
apps in the launcher. Log out and back in to pick up shell and session changes.

Worth opening one config you actually customised — `~/.config/hypr/bindings.lua`
or your Neovim setup — and confirming it is yours and not a default.

## 4a. Validate applied-loadout lifecycle

Use two disposable profiles with one overlapping package, a compatible pinned
plugin shared by both, and distinct pinned themes. Do not use production-only
software or the live vault.

```bash
ress apply /path/to/loadout-a
ress apply /path/to/loadout-b
ress loadout list --details
ress resource show package:<shared-name>
ress loadout check
```

Remove one disposable integration outside ress, confirm check reports it
missing without reinstalling it, then preview and run repair. Change one profile
and verify ordinary apply refuses silent replacement before running
`ress loadout update ID`.

Remove the loadouts in both orders. Record that the first shared claim is only
released, the final unchanged ress-introduced resource is cleaned, a
pre-existing resource remains, and a deliberately modified plugin requires the
keep/remove decision. For packages, capture both a successful direct removal
and a real dependency refusal; verify no orphan is automatically removed.

Finally, apply two disposable themes. Removing the effective request should
activate the remaining request before deleting its theme; removing the final
request should restore the original baseline. Repeat after manually selecting
a third theme and confirm cleanup preserves that external selection.

Open the panel Loadouts tab and record count/attention, keyboard row selection,
metadata/content detail, and update/repair/remove terminal handoff. Confirm no
privilege or destructive prompt occurs behind the panel.

## 5. What to record

- The **whole run** as one take, failures included.
- The final line: `This machine is yours again — in 14s.`
- `ress verify` afterwards, saying it matches.
- The desktop afterwards.

### Share composer checklist

On a clean Omarchy desktop with a large explicit package inventory, open Share
directly with the `s` shortcut and through the named-tab IPC entry. Record:

- loading, unavailable, explicit-start, compose, exporting, and refusal views;
- All resources, Current export, Empty selection, and an applied-loadout start;
- name and description editing, category entry, bounded search, pointer toggles,
  keyboard toggles, radio-style theme replacement, and Escape back to navigation;
- adding a second applied loadout, including excluded-resource warnings and a
  conflicting theme that preserves the existing choice;
- an unavailable current-export entry remaining visible until its individual
  withdrawal acknowledgement, plus stale-fingerprint refusal and catalog
  refresh without a false success notice;
- responsive scrolling/search with the large package list and no full package
  inventory rendered at the top level;
- successful schema-version-1 dry-run apply of the composed result; and
- continuity of the profile folder, existing Git remote/history, copied share
  command, and configured profile URL.

Capture pointer and keyboard focus separately. Automated model tests, QML lint,
and CLI fixtures do not prove rendered focus, click targets, scroll behavior, or
large-list frame responsiveness.

No recorder ships by default. Either `sudo pacman -S wf-recorder` inside the VM,
or record the VM window from the host — which also captures the boot and keeps a
recorder out of the machine you are presenting as fresh.

## What the first real run found

Run on a clean Omarchy VM on 19 Aug 2026. It completed in **14 seconds**, and it
found three bugs that no amount of local testing had:

- Empty fields in the plugin list shifted every later column, because tab is IFS
  whitespace and `read` collapses runs of it.
- A fresh Omarchy carries the ISO's `offline.db` and none of the online package
  databases, so every install failed with `target not found`. Checking whether
  any database file exists is not enough; the fix installs, and refreshes and
  retries only on failure.
- A category that failed was still recorded as done, so "rerun to pick up where
  it stopped" skipped the step that had failed.

Still not exercised: encrypted secrets, since `age` is not installed on the
source machine.

## Applied-loadout clean-VM run — 2026-10-04

Two Proxmox VMs running Omarchy `4.0.0.alpha` and kernel
`7.2.5-3-omarchy` were used. Both began without a ress registry, the ress
plugin, user themes, or the disposable packages. The target also had no running
Omarchy shell, which exercised the TTY/SSH path rather than borrowing a desktop
session. The pinned fixtures and repeatable driver are
`tests/manual/vm-loadout-{a,b}.json` and
`tests/manual/run-vm-loadout-lifecycle.sh`.

The six original fresh-machine boundaries were recorded separately so this run
does not imply more than it observed:

| Boundary | Observation |
|---|---|
| Real package installation | `pacman` installed `tree`, `figlet`, and `sl` from the Arch repositories during confirmed loadout apply. No AUR package was requested, so AUR build behavior remains unobserved in this run. |
| Genuine initial absence | Preflight confirmed all three packages, both user themes, both launchers, the plugin, and the ress registry absent on the target. |
| Panel drawing | The source's live Omarchy shell rendered the Loadouts tab with two healthy rows, count and resource totals. Keyboard selection exposed metadata and content, and Remove opened a visible terminal with the exact CLI command. Cancelling before confirmation left both loadouts healthy and `operation` null. The tight panel capture is `docs/media/loadouts.png`. |
| Units starting on login | Not exercised; neither disposable profile carries systemd units. |
| Theme application | Real theme commands changed recorded machine state through Sunset Drive, Hermarchy, fallback, baseline restoration, and an external Tokyo Night override. On the running source desktop, the observer visibly confirmed Sunset Drive → Hermarchy after removing A and Hermarchy → Tokyo Night after removing B. |
| Restore timing claim | Not measured. This was an applied-loadout lifecycle run, not a timed full-vault restore, so the existing README restore timing is neither refreshed nor generalized from it. |

The applied-loadout observations were:

- applying A then B installed exclusive resources and shared `tree` plus the
  pinned ress plugin; `loadout list`, `resource show`, and `loadout check`
  reported two healthy loadouts and both claimants;
- deleting a source launcher outside ress made check report it missing, repair
  reinstalled it, ordinary apply refused a changed known source, and explicit
  update withdrew the launcher and added the requested package;
- both removal orders released the first shared claims and removed final,
  unchanged ress-introduced resources; real direct `pacman -R` transactions
  removed `tree`, `figlet`, and `sl` without an orphan sweep;
- a deliberately dirty plugin produced `DECISION-REQUIRED` before any removal
  transaction began; `--keep-modified` relinquished cleanup authority and
  preserved it until separate disposable cleanup;
- removing the effective theme selected the remaining request before deleting
  its files, final removal restored Tokyo Night, and a later external Tokyo
  Night selection survived loadout cleanup;
- on the rendered source desktop, the observer confirmed Hermarchy was visible
  after the first removal and Tokyo Night was visible after the final removal;
  the CLI simultaneously confirmed the outgoing theme directory was absent;
- the final target registry had zero loadouts, resources, and claims with no
  operation; all disposable packages, themes, launchers, and the plugin were
  absent, while the unrelated application-data canary remained unchanged.

The VM run found two real integration gaps. Omarchy's web-app remover can delete
the launcher and then return nonzero from its desktop-database refresh; ress now
decides that case by reinspection instead of retaining a ghost claim. Omarchy's
plugin remover queries live shell IPC before deletion; when IPC is confirmed
absent, ress reruns the same supported remover with narrowly scoped
no-live-shell answers for the enabled-state query and rescan. Omarchy still
performs validation and deletion. Both gaps have focused automated assertions.

Still not claimed from this run: AUR builds, systemd units starting after login,
encrypted secrets, a timed full restore, or enabled-plugin unload through a
live shell on the clean target.

## Share-composer clean-VM boundary — 2026-10-05

Run on a disposable Omarchy 4.0.4 VM (`7.2.5-3-omarchy`) with the plugin linked
from this change and enabled in the live shell. The initial catalog contained
185 resources: 162 explicit packages, one plugin, no user web apps, and 22
themes. A representable test web app raised the later total to 186. A final
direct catalog read completed in 2.638 seconds. The panel kept the full package
inventory behind its category and bounded search view; opening categories,
filtering to one result, and toggling it showed no observed input stall. This
was an interaction observation, not a frame-time benchmark.

The rendered panel established the following manual-only evidence:

- named-tab IPC opened Share directly and showed a loading view followed by the
  explicit All resources, Current export, Empty selection, and applied-loadout
  starts;
- the keyboard path started from All resources, edited the default
  `montagetest's Omarchy` name and description, searched packages, toggled a
  result, and returned from each text field with Escape;
- a Wayland virtual pointer started from Empty selection and toggled the
  rendered `aether` package control; a separate pointer path selected
  `catppuccin-latte` and then `gruvbox`, and the exported schema-1 profile
  contained exactly the final `gruvbox` theme;
- two real applied loadouts supplied preset starts and additive actions. After
  the first loadout's web-app definition was changed, its excluded-resource
  warning named that web app. Adding the second loadout retained the already
  selected conflicting theme and displayed the instruction to choose another
  theme explicitly;
- changing an unavailable current-export web app after its acknowledgement
  changed the catalog fingerprint. Export refused with
  `acknowledgement required`, preserved the profile, refreshed the catalog,
  retained safe selections, discarded the stale acknowledgement, and did not
  show a success notice. Acknowledging the refreshed fingerprint then exported
  successfully;
- the busy `Reading this machine`/export state, the refusal wording, preset
  warning, current-definition replacement wording, and successful return to the
  composer were all visible in the rendered panel;
- the profile-folder action opened the existing profile directory, the copy
  action produced the configured `ress apply ...` form, and repeated panel
  exports retained the Git repository and accumulated history; and
- after adding a non-network test GitHub remote, a further selective export
  retained that remote and history and set `PROFILE_URL` to
  `ress.sh/gh/montagetest/ress-vm-evidence`. Applying the composed schema-1
  profile with `--dry-run` parsed it through the existing apply path and
  produced the expected theme install/activation plan without mutating the VM.

The VM's Omarchy theme command did not resolve the catalog-advertised bundled
theme names when the applied-loadout fixtures were first created, so this run
does not claim a live theme activation. The compose/export contract and
schema-1 dry-run compatibility were observed. The whole-catalog unavailable
pane was not deliberately induced, and no profile was pushed to a hosted
remote; those remain outside this run rather than inferred from automated
tests.
