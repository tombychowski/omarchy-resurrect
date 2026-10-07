# Fresh-machine validation

Run this checklist on a disposable, clean Omarchy machine or VM. It is release
evidence, not an automated test. Use private repositories and disposable
fixtures; never point it at valued Ress or Montage state.

Record the date, Montage commit, Omarchy version, kernel, package manager,
display scale, shell version, Git version, GitHub repository visibility, and
whether the environment is physical or virtual.

## 1. Establish command and plugin coexistence

This section proves side-by-side Ress and Montage installation plus independent
plugin lifecycle on a clean Omarchy machine.

Install the published Ress plugin using its own documented source. Record its
plugin id and verify its `ress` command before installing Montage. Then:

```bash
omarchy plugin add https://github.com/tombychowski/omarchy-montage --enable
~/.config/omarchy/plugins/tombychowski.montage/bin/mntg link
command -v mntg
command -v ress
command -v montage
```

Expected observations:

- both plugins are visible under distinct ids;
- `mntg`, `ress`, and ImageMagick `montage` resolve to distinct executables;
- Montage does not modify Ress XDG roots or its command;
- a pre-existing unrelated `~/.local/bin/mntg` is refused rather than replaced;
- `mntg link --remove` removes only a Montage-owned link; and
- updating or removing either plugin leaves the other working.

## 2. Initialize independent native repositories

Authenticate with a Git credential helper or SSH-agent; never embed credentials
in a remote URL.

```bash
mntg init
mntg repository init loadouts "$HOME/.local/share/montage/loadouts" --id vm-loadouts
mntg repository configure vm-vault "$HOME/.local/share/montage/vault" vault \
  --remote git@github.com:OWNER/PRIVATE_VAULT.git
mntg repository configure vm-loadouts "$HOME/.local/share/montage/loadouts" loadouts \
  --remote git@github.com:OWNER/PUBLIC_OR_PRIVATE_LOADOUTS.git
mntg repository list --json
```

Expected observations: native `montage.json` controls validate, repository ids
are stable, remotes contain no credentials, the vault remote is private, and no
Ress path is configured as live Montage state.

On a disposable public GitHub repository, attempt the vault configuration once
without confirmation, then confirm only for the purpose of the test and remove
the configuration immediately:

```bash
mntg repository configure public-warning "$HOME/.local/share/montage/vault" vault \
  --remote git@github.com:OWNER/DISPOSABLE_PUBLIC_REPO.git
```

Expected observation: Montage identifies known-public visibility, explains that
vault metadata and encrypted-secret ciphertext may be exposed, and refuses
without explicit confirmation. Unknown visibility is reported as unknown, not
silently claimed private.

## 3. Capture, history, sync, and divergence

Create at least three distinct backups and label the middle one:

```bash
mntg backup --message first
mntg backup --message middle
mntg backup label before-change HEAD
mntg backup --message latest
mntg backup list --json
mntg repository sync vm-vault --push
```

On a disposable second clone, add and push a commit; add a different local
backup on the first machine. Run `mntg repository sync vm-vault --json`.

Expected observations: equal/local-ahead/remote-ahead states permit only their
history-preserving actions; the constructed split reports `divergent`; Montage
does not merge, reset, or force-push; the panel shows **Review divergence in
terminal**.

## 4. Exact historical restore

Select the oldest backup in the panel **Repositories** tab and activate
**Restore this exact backup**. Record the full commit shown before confirmation.
Cancel once, then repeat against disposable machine state and confirm.

Expected observations: the terminal command is pinned to the selected full
commit, previews repository and backup identity, preserves replaced files as
`.montage-bak`, keeps AUR and service consent separate, and resumes only against
the same repository/commit. `mntg verify --backup COMMIT` reports the restored
state without drifting to HEAD.

## 5. Loadout library and applied state

Create at least two repository loadouts. From the panel, keyboard-select the
repository and one stable item, open **Compose selected loadout**, publish a
small selection, preview apply, apply it on a clean target, and inspect:

```bash
mntg repository loadouts vm-loadouts --json
mntg loadout list --json --contents
mntg loadout check --json
```

Expected observations: sibling loadouts remain unchanged, share/apply retain
repository id/loadout id/commit provenance, package and AUR decisions are
visible, and removal never claims pre-existing or imported legacy ownership.

## 6. Panel rendering and keyboard evidence

Capture all four tabs at the supported scale. Exercise pointer and keyboard
paths separately, including `b`, `r`, `o`, `s`, `a`/`l`, arrows, Enter, and
Escape from every text field.

Record rendered examples of empty, invalid, loading, healthy, stale, divergent,
and attention repository states. Confirm long content scrolls, focus remains
visible, and repository/settings fields do not overflow. Capture terminal
handoffs for restore, retention, sync, loadout mutation, and port publication
before confirmation.

## 7. Ress v1 port validation

Work only on disposable copies. Record source hashes and Git status before and
after each command.

```bash
cp -a -- /path/to/ress-loadout /tmp/ress-loadout-copy
cp -a -- /path/to/ress-vault /tmp/ress-vault-copy
mntg port ress inspect /tmp/ress-loadout-copy --json
mntg port ress plan /tmp/ress-vault-copy --destination /tmp/montage-vault --json
```

Validate current loadout import, current vault import, and optional history
translation. Include a bad middle revision and verify default all-or-nothing
behavior. Exercise explicit compatible-subset/loss consent separately. Export
one selected native loadout and one selected backup into empty staging paths,
then validate those copies with the supported Ress v1 baseline.

Expected observations: sources remain byte-for-byte or Git-status unchanged;
destinations are separate; native ids/commits/remotes are newly established;
private identities, locks, progress, config, and cleanup ownership do not cross;
and self-plugin entries require explicit decisions.

## 8. Independent removal and cleanup

```bash
mntg link --remove
omarchy plugin remove tombychowski.montage
```

Expected observations: Ress remains enabled and usable, ImageMagick `montage`
is untouched, and user-owned Montage repositories/state remain until explicitly
reviewed and removed. Reinstall Montage and verify repository configuration can
be re-established without adopting Ress paths.

## Evidence log

Create one dated subsection per run with environment, exact commit, commands,
expected and actual observations, screenshots, failures, and cleanup. The
current Montage release checklist is **not yet recorded as executed** until a
dated run is added here. Historical Ress-era evidence may be kept in archived
change records but does not satisfy this checklist.

### 2026-10-06 — Omarchy 4.0.4 KVM (`montage-source`)

Run status: the named clean-machine integration and Ress v1 port checks in
OpenSpec tasks 9.4 and 9.5 completed across 2026-10-06 and 2026-10-07. A local
Git transport was used first to establish deterministic divergence evidence;
the GitHub continuation below separately proves authenticated private sync and
the known-public vault warning.

Environment and source:

- KVM guest, Omarchy `4.0.4-1`, kernel `7.2.5-3-omarchy`, Hyprland on
  `Virtual-1` at 1280×800 and scale 1;
- Quickshell `0.3.1`, Git `2.55.0`, jq `1.8.2`;
- local source base `dca36eb96737a53108536ce8fb3caee6e48ab64e` with the
  uncommitted change snapshot installed as commit
  `1706db73d370fa7dc43f3152f67424e481899135`, tree
  `37f2611e097c4e5749f7816ee971155df2c84c27`, and pre-transfer file-manifest
  digest `57f3aa9039bbac078c12c0dff2aa40afb2e624b05ac9f36040f3fe8a627e5920`;
- published Ress commit `19a20b84bb66fc36020694d5957604a7f25e1e0e`;
- disposable evidence root
  `/home/montagetest/montage-validation/20261006T2345`; and
- GitHub authentication was initially absent, then completed on 2026-10-07 as
  account `tombychowski` using the HTTPS credential helper. No credential was
  printed, embedded in a URL, or written to Montage configuration.

Coexistence and lifecycle observations:

- `omarchy plugin add https://github.com/btsouth/omarchy-resurrect --enable
  --yes` installed `tsouth89.resurrect`; `omarchy plugin add
  file:///home/montagetest/montage-validation/20261006T2345/source --enable
  --yes` independently installed `tombychowski.montage`.
- `ress` and `mntg` resolved to their respective plugin-owned links.
  ImageMagick remained `/usr/bin/montage`, whose packaged target is
  `/usr/bin/magick`. Both product CLIs reported version `1.2.0`.
- An unrelated regular file at `~/.local/bin/mntg` was refused with exit 1 and
  identical before/after SHA-256
  `f641f022503420433a082e885647810297b74db84e34a743976893e73e7e20cc`.
  Owned link removal removed only `mntg`, and relinking restored it.
- Independent `omarchy plugin update` calls reported each plugin current.
  Removing and reinstalling Ress left Montage and its repositories usable;
  removing and reinstalling Montage left Ress and ImageMagick usable. The
  configured `vm-vault` and `vm-loadouts` repositories survived Montage
  removal. Ress configuration, state, and data roots remained absent.

Native history, synchronization, and panel observations:

- A disposable vault created five exact backups. Restoring commit
  `dae2ddb419da91864849151800b3ac2ee0fd31e7` with only the config category
  restored probe value `first`, preserved replaced value `second` as
  `value.montage-bak`, and `mntg verify --backup` reported `complete: true`
  against that same full commit.
- A real local `git daemon` remote first classified `equal`. Independent local
  and remote commits then classified `divergent`, ahead 1 and behind 1. An
  attempted `--push` returned exit 3 with `decision-required` and
  `divergent-history`; neither ref changed. The daemon was stopped after the
  run.
- The live panel rendered all four tabs at scale 1. Keyboard `o`, `s`, `l`,
  `?`, `b`, and `r`, arrows, Enter, and text-field Escape were exercised.
  Escape returned focus from the repository-name field before `s` opened
  Share. Keyboard `b` advanced `last-attempt` from `1791351890` to
  `1791352048`.
- Keyboard-only repository and backup selection rendered the divergent state
  and opened a Foot terminal pinned to full commit
  `ea61ee98058fd3d9426a9ea3aff691b5b1ea1334`. The terminal displayed the
  repository id `vault-ca3385db2363`, exact commit, executable-content warning,
  and restore confirmation. It was closed without confirmation.
- Cropped captures and SHA-256 values are retained below the evidence root in
  `panel4/` and `panel-repository2/`. Representative hashes are
  `7a3cfce1bb1cdb6bd5991d1e61b26829f530a244e7be81e2a8fd7b08d8b97f74`
  (Repositories),
  `8a5cdc5a75334f5eb949c12875648b17aed075595cd801acfea55c538d58f82e`
  (Share after field Escape),
  `c60b248b7353cc7fca94be8bd47da6e6c9d6f3aeec37a5623c1d318d3dcd0ece`
  (Loadouts),
  `9b56d396c2b344dec931dde0c2234d6207331628e01c0842153efd84c779127a`
  (Backup),
  `f2362c8ff5ff9593f1636649b87ba7e6df2dc3594f289697f8b9a9aafd0a2ded`
  (restore row focus), and
  `955b35015dd39d63785cad8d364d769faa2c757767594fc765ee864145cb0d82`
  (unconfirmed exact-restore prompt).

GitHub continuation on 2026-10-07:

- `tombychowski/montage-private-test` resolved as private and
  `tombychowski/montage-public-test` resolved as public. Both began with no
  refs. The private repository was seeded from the disposable vault by one
  ordinary, non-forced initial push; the public repository remained empty.
- Configuring the public repository as vault storage without confirmation
  returned exit 1 and wrote no registry entry. Explicit confirmation returned
  `visibility: "public"` and warned that personal backup metadata and
  encrypted-secret ciphertext could be exposed. The temporary
  `public-warning` entry was removed immediately.
- Configuring `vm-vault` with the credential-free private HTTPS URL returned
  `visibility: "private"` and no warning. Initial synchronization classified
  `equal` at `ea61ee98058fd3d9426a9ea3aff691b5b1ea1334`.
- A local backup produced `local-ahead` by one commit, and `mntg repository
  sync vm-vault --push` performed a normal push to
  `eee6c7c4987d8864e66108e2feee1a3238747f79`. A valid commit from a second
  clone then produced `remote-ahead` by one; `--pull` performed a validated
  fast-forward to `b5ef5d255600e67d8f06eb50b29f857fa480533c`.
- Independent local and remote commits produced `divergent`, ahead 1 and behind
  1, at local `20b5f4265e5def182aec103deb751bd7ce9b5628` and remote
  `9a5fdf8b932cac0abf8579b3ffd69d85848d2245`. An attempted `--push` returned
  exit 3 with `decision-required` / `divergent-history`; both refs remained
  unchanged.
- The split was resolved manually in the peer clone, not by Montage. Montage
  then classified `remote-ahead`, fast-forwarded two commits, and finished
  `equal` at `b9f161f40c151393bfbe70c06d28d8fe2d413888`. The temporary resolution
  branch was deleted; no force push, reset, automatic merge, or credentialed
  remote was used.

Ress v1 port observations:

```bash
mntg port ress inspect SOURCE --json
mntg --dry-run port ress import loadout SOURCE --repository vm-imports --loadout workstation --json
mntg --yes port ress import loadout SOURCE --repository vm-imports --loadout workstation --json
mntg --dry-run port ress import vault SOURCE --destination DESTINATION --ress-plugin omit --montage-plugin include --json
mntg --yes port ress import vault SOURCE --destination DESTINATION --ress-plugin omit --montage-plugin include --json
mntg --dry-run port ress import vault HISTORY_SOURCE --destination HISTORY_DESTINATION --history --json
mntg --yes port ress import vault HISTORY_SOURCE --destination HISTORY_DESTINATION --history --compatible-only --accept-loss unsupported-history-revisions --json
mntg --yes port ress export loadout LIBRARY --loadout workstation --destination LOADOUT_EXPORT --accept-loss montage-repository-metadata --json
mntg --yes --vault NATIVE_VAULT port ress export backup --backup COMMIT --destination VAULT_EXPORT --accept-loss montage-vault-identity --montage-plugin map-ress --json
```

- Current loadout import preserved the portable profile, sibling loadout,
  source history/status/remote, destination remote, and applied-state boundary.
- Current vault import required explicit Ress/Montage self-plugin decisions,
  created fresh repository and machine ids plus one fresh commit, and inherited
  no source remote.
- Three source history commits included an unsupported middle revision. Default
  dry-run and live import returned exit 3 and published nothing. Explicit
  compatible-subset consent translated the first and third revisions into two
  new commits and itemized the omitted source hash.
- Before/after snapshots for all three sources combined payload SHA-256, HEAD,
  porcelain-status digest, and `.git/config` SHA-256. Every final snapshot was
  identical to its initial value.
- Selected loadout and backup exports left native HEAD, status, and remote
  configuration unchanged. `mntg port ress inspect` accepted both exports as
  compatible format `ress-v1`; published Ress also accepted the exported
  `profile.json` through `ress --dry-run apply`.

Additional marketplace media work remains beyond the named OpenSpec integration
tasks: complete the pointer and screen-reader passes plus the full selected-
loadout, retention, mutation, and port-terminal screenshot matrix before using
this run as the final marketplace media set. Those captures are release-media
breadth, not exceptions to the completed command, isolation, synchronization,
divergence, restore, or port guarantees recorded above.
