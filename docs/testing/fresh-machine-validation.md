# Fresh-machine validation

Run this checklist only on a disposable clean Omarchy installation or VM. For
every observation record date, Montage commit, Omarchy/OS and tool versions,
commands, expected result, actual result, artifacts, and cleanup. Mark anything
not executed as **deferred**, not passed.

Prepare and reset the two disposable guests with the
[Proxmox VM runbook](disposable-vm-runbook.md), including its exact handoff
prompt and evidence-before-reset procedure.

## 1. Install, identity, and coexistence

- Install Montage and optionally Ress side by side.
- Confirm `mntg`, Ress's command, and ImageMagick `montage` resolve independently.
- Exercise guarded `mntg link`, foreign-target refusal, owned removal, and relink.
- Update and remove either plugin; verify the other still works.

## 2. Create a disposable library

```bash
mntg repository init "$HOME/.local/share/montage/vm-loadouts" --id vm-loadouts
mntg repository configure vm-loadouts "$HOME/.local/share/montage/vm-loadouts" \
  --remote REMOTE_WITHOUT_USERINFO
mntg repository list --json
```

Confirm modes, exact envelope identity, schema-2 configured registry,
credential-free output, and that malformed or wrong-kind paths are refused.

## 3. Compose, publish, and synchronize

Use the Compose/Share panel and CLI to publish package, pinned plugin, web-app,
and theme resources. Confirm unsafe launchers, credentialed URLs, unpinned
integrations, and unavailable withdrawals are explained and refused without
the required acknowledgement.

With a disposable remote, record equal, local-ahead, remote-ahead, and divergent
classification. Authenticate through a Git credential helper or SSH-agent.
Confirm pull is fast-forward-only, push is non-forced, divergence remains a
terminal decision, and ordinary status makes no network request.

## 4. Apply and reconcile

Preview and apply one library item. Exercise native and AUR packages with
`ask`, `yes`, and `no`; inspect the PKGBUILD review path. Confirm declined work
remains pending. Exercise pinned plugin, web-app, installed theme, and active
theme effects.

Run check, repair, update preview, update, and remove. Verify:

- unrelated state remains;
- pre-existing and shared resources are retained;
- modified or unverifiable resources require an explicit decision;
- package cleanup does not cascade or infer orphan cleanup;
- explicit update preview creates update attention without changing desired state; and
- removal changes only resources justified by native claims.

## 5. Configured-registry migration

Use a disposable copy of a pre-change schema-1 configured registry containing
valid loadout entries and inert legacy entries. Trigger first read. Confirm one
revision increment, deterministic retained ordering, exact mode-0600
`.pre-schema2` copy, migration reporting, retry stability, and zero reads or
writes below retired paths. Keep the original fixture for comparison.

## 6. Ress v1 migration

Keep source and destination on separate disposable paths:

```bash
mntg port ress inspect RESS_SOURCE --json
mntg --dry-run port ress import loadout RESS_SOURCE \
  --repository vm-loadouts --loadout imported-ress \
  --ress-plugin omit --montage-plugin omit --json
mntg port ress import loadout RESS_SOURCE \
  --repository vm-loadouts --loadout imported-ress \
  --ress-plugin omit --montage-plugin omit
```

Record source tree bytes and metadata before and after. Verify one item is
published, siblings and remote identity remain, self-plugin/loss decisions are
identical across inspect/dry-run/live planning, and unsupported foreign
authority is not adopted.

## 7. Rendered panel and keyboard

Capture Libraries, Compose/Share, and Applied Loadouts at normal and constrained
height. Verify all attention summaries, per-cause detail, active animation,
valid empty and invalid states, mouse/keyboard parity, focus return, scrolling,
Share search/selection/withdrawal acknowledgement, divergent sync handoff, Ress
inspection/publication handoff, and lifecycle terminal actions.

## 8. Final cleanup

Remove disposable libraries, remotes, imported item, test resources, temporary
credentials, screenshots not selected as evidence, and Montage if the VM is for
installation testing. Verify removal leaves unrelated Ress installation and
foreign PATH targets untouched.

## Current evidence record

No clean-machine or rendered result is implied by this checklist. Add dated,
commit-specific pass/fail/deferred observations below only after execution.

### 2026-10-07 — apply-step deferral

- **Commit:** implementation working tree based on
  `9a86febbf18c7a1bcb22d02f8995db3d4beeb954`.
- **Environment:** Codex workspace on Omarchy 4.0.4, Linux
  7.2.3-arch1-3 x86_64, Montage 1.0.0. This is the development host, not a
  disposable clean installation or fresh VM.
- **Result:** **deferred** for real Git synchronization and credential-helper or
  SSH-agent behavior; native/AUR package operations; plugin, theme, and web-app
  effects; side-by-side Ress isolation; install/update/remove behavior; and
  rendered mouse/keyboard panel validation.
- **Observation:** automated doubles, fixtures, QML/model checks, mutation
  detectors, and the full suite cover the corresponding boundaries without
  claiming real-tool, network, rendered-layout, or clean-machine execution.
- **Cleanup:** no external resources, credentials, packages, remotes, panel
  captures, or disposable machines were created, so no real-machine cleanup
  was required.

### 2026-10-07 — two-VM execution

- **Commit:** uncommitted implementation working tree based on
  `9a86febbf18c7a1bcb22d02f8995db3d4beeb954`, staged to the VMs as a byte copy;
  Montage reports version 1.0.0.
- **Environment:** two disposable x86_64 Omarchy 4.0.0.alpha VMs on Linux
  7.2.5-3-omarchy. `mantage-target` at 192.168.68.160 was the clean lifecycle
  and rendered-panel target; `montage-source` at 192.168.68.154 hosted bare Git
  peers. The target display was a 1280x800 QEMU monitor with a live Hyprland and
  Quickshell session. Neither VM initially allowed `sudo -n`; the operator later
  added a temporary rule granting `montagetest` passwordless access to
  `/usr/bin/pacman` only on the target.
- **Passed — real tools and SSH Git:** `tests/manual/loadout-real-scratch.sh`
  passed on the target with real `pacman` planning and real Omarchy
  plugin/web-app/theme removal commands in its disposable home. A disposable
  ED25519 key was loaded into `ssh-agent`, never placed in a repository URL,
  and used against the peer VM. Real `mntg repository sync` calls classified
  equal, remote-ahead, local-ahead, and divergent histories; explicit pull was
  fast-forward-only, explicit push was non-forced, and the divergent pull
  returned decision-required while both commit ids remained unchanged. An SSH
  transport that would create a marker if invoked confirmed ordinary
  `mntg status --json` performed no repository network request.
- **Passed — installation identity and rendered shell:** Omarchy cloned,
  validated, discovered, enabled, fast-forward updated, disabled, and removed
  the Git-managed Montage plugin. `mntg link` created and idempotently relinked
  only its owned symlink, removed it, refused a byte-preserved foreign target,
  and relinked after that target was explicitly removed. Removing Montage
  unloaded it while `omarchy.bar` remained active and `/usr/bin/montage`
  remained the ImageMagick command. The installed panel rendered Libraries,
  Compose/Share, and Applied Loadouts at 1280x800, including empty states, a
  configured library, stable-item selection, apply/compose actions, and the
  populated live package catalog. Real `wtype` input exercised `l`, `c`, and
  `a` tab shortcuts, arrow/Enter library and loadout selection, Compose entry,
  and Escape closure.
- **Passed — migration boundaries:** a real first CLI read migrated a private
  schema-1 mixed configured registry to schema 2, incremented revision 7 to 8,
  retained loadouts in deterministic order, reported sorted retired vault
  names, and created a byte-exact mode-0600 `.pre-schema2` copy. A second read
  rewrote neither document, and the permission-blocked retired-path canary's
  bytes and observed metadata were unchanged. Ress v1 inspect, dry-run, and
  confirmed import published exactly one native item and commit while
  preserving a sibling, destination remote configuration, private applied
  state, and the source's bytes, metadata, history, worktree, and remote
  configuration; implicit replacement of the stable item was refused without
  another commit.
- **Passed — tracked native lifecycle:** after the pacman-only sudo rule was
  present, `tests/manual/run-vm-loadout-lifecycle.sh` completed all three
  cycles. Real pacman installed and removed `tree`, `figlet`, and `sl`; pinned
  plugin, pinned theme, web-app, and active-theme effects were installed,
  checked, shared, released, and removed. Both removal orders retained shared
  resources until the final claim, effective theme selection followed
  precedence, final removal restored `tokyo-night`, and an external selection
  of that baseline was not overwritten. Dry-run removal changed nothing. A
  deliberately modified plugin produced decision-required without starting a
  removal transaction; `--keep-modified` preserved it before explicit Omarchy
  cleanup. The unrelated canary remained byte-identical, zero pre-existing
  orphans were observed, no orphan sweep was inferred, and the final registry,
  packages, plugin, themes, and web apps were empty/absent.
- **Fixture qualification:** the checked-in manual profiles' plugin URL,
  `https://github.com/tombychowski/omarchy-montage`, returned repository-not-found
  from the VM, so the first attempt correctly finished partial with a missing
  plugin and its tracked removal restored baseline. An SSH resource URL was
  then correctly refused as non-HTTPS and that second tracked run also cleaned
  to baseline. The passing run used VM-staged profile copies pinned to commit
  `51f5033e87205ba8063d07980634b508f25dd5eb` at a loopback-only HTTPS fixture
  on the peer reached through a loopback-only SSH tunnel. The fixture preserved
  Montage's canonical HTTPS identity; self-signed TLS relaxation was scoped to
  that exact loopback URL. The checked-in default profiles therefore still
  require a reachable public plugin URL before this script is reproducible
  without fixture substitution.
- **Deferred — remaining interaction coverage:** a live side-by-side Ress
  installation, credential-helper authentication (SSH-agent authentication did
  pass), AUR `ask`/`yes`/`no` and PKGBUILD-review paths, explicit repair/update
  preview/update commands, pre-existing resource retention, mouse parity,
  pointer-wheel scrolling, focus return to a pre-existing application window,
  and a second normal-height display capture were not executed. Page Down did
  not provide evidence of pointer scrolling and is not counted as a pass.
- **Artifacts and cleanup:** selected target logs and PNG captures are retained
  at `~/.local/share/montage-validation-evidence-2026-10-07/`. The target
  validation tree and private key, SSH tunnel, peer HTTPS server, bare remotes,
  peer worktree, helper, exact disposable authorized-key line, generated
  Montage config/state, canary, installed plugin, PATH link, live panel library,
  and all fixture package/plugin/theme/web-app state were removed. Pre-existing
  Ress backup and launcher artifacts on the peer were left untouched. The
  operator-added `/etc/sudoers.d/montage-vm-test` rule remains for the operator
  to remove from the Proxmox console because the SSH account is intentionally
  authorized for pacman only.
