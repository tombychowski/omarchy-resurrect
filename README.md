# Montage

<p align="center"><strong>Compose, share, apply, and reconcile portable Omarchy loadouts.</strong></p>

Montage is an independent project and Omarchy plugin. A loadout is a constrained
declarative profile for packages, pinned plugins, reconstructible web apps, and
one theme. It contains no arbitrary files, commands, services, credential
material, or implicit cleanup authority.

The `mntg` CLI is the product authority. The bar panel presents its versioned
results through three surfaces: Libraries, Compose/Share, and Applied Loadouts.

## Install and link

Install the plugin through Omarchy, then optionally place its guarded CLI link
on your PATH:

```bash
~/.config/omarchy/plugins/tombychowski.montage/bin/mntg link
mntg doctor
```

The plugin id is `tombychowski.montage`. `mntg link` refuses to replace a
foreign `~/.local/bin/mntg`; `mntg link --remove` removes only the active
Montage-owned link.

## Create a loadout library

```bash
mntg repository init "$HOME/.local/share/montage/loadouts" --id personal-loadouts
mntg repository configure personal "$HOME/.local/share/montage/loadouts" \
  --remote https://github.com/you/omarchy-loadouts.git
mntg repository list --json
```

Libraries are ordinary local Git repositories with one fixed Montage envelope
and stable items at `loadouts/<stable-id>/profile.json`. Remotes are optional;
authentication belongs to Git credential helpers or an SSH agent, never stored
URLs.

## Compose and share

Inspect the safe current-machine catalog:

```bash
mntg share catalog --repository personal --loadout workstation --json
```

Publish an explicit non-empty selection:

```bash
mntg share --repository personal --loadout workstation --custom \
  --name "My workstation" \
  --select package:fd \
  --select plugin:acme.example
```

The CLI resolves logical ids against a fresh catalog, stages a complete item,
validates it, preserves siblings, and commits only a content change. An
unavailable prior definition requires its exact fingerprint before withdrawal.

## Inspect and apply

```bash
mntg repository loadouts personal --json
mntg apply --dry-run personal --loadout workstation
mntg apply personal --loadout workstation
```

Apply is additive. Existing unrelated state remains untouched. Pre-existing
resources are protected, shared resources remain while claimed, and removal
uses only validated claims recorded by a successful native apply. AUR builds
require a separate decision; set the default with:

```bash
mntg set AUR=ask   # or yes / no
```

## Reconcile applied loadouts

```bash
mntg status --json
mntg loadout list --json --contents
mntg loadout check --json
mntg loadout repair LOADOUT_ID
mntg loadout update --dry-run LOADOUT_ID
mntg loadout update LOADOUT_ID
mntg loadout remove LOADOUT_ID
mntg resource list --json
```

Status classifies live operations, incomplete operations, unavailable evidence,
library decisions, drift, repair work, explicitly previewed updates, and healthy
state. Ordinary status is local and non-mutating.

## Synchronize a library

```bash
mntg repository sync personal --json
mntg repository sync personal --pull
mntg repository sync personal --push
```

The first command explicitly fetches and classifies. Pull is fast-forward-only,
push is ordinary and non-forced, and divergence requires a visible user
decision. See [Synchronize libraries](docs/workflows/repository-sync.md).

## Import one Ress v1 loadout

Montage has one frozen foreign-input boundary:

```bash
mntg port ress inspect /path/to/ress/profile-or-directory --json
mntg --dry-run port ress import loadout /path/to/ress/profile-or-directory \
  --repository personal --loadout imported-ress \
  --ress-plugin omit --montage-plugin omit --json
mntg port ress import loadout /path/to/ress/profile-or-directory \
  --repository personal --loadout imported-ress \
  --ress-plugin omit --montage-plugin omit
```

The source is read-only. Montage imports no Ress configuration, remotes, locks,
operational state, claims, credentials, keys, machine identity, or Git history.
There is no reverse conversion. See [Ress migration](docs/workflows/ress-portability.md).

## Command surface

```text
mntg repository <init|list|show|validate|configure|remove|loadouts|loadout|sync>
mntg share [catalog] ...
mntg apply SOURCE --loadout ID
mntg loadout <list|show|check|repair|update|remove>
mntg resource <list|show>
mntg port ress <inspect|import loadout>
mntg status [--json]
mntg set AUR=<ask|yes|no>
mntg doctor
mntg link [--remove]
```

## Scope and safety

Montage manages portable setup choices, not personal data. Use dedicated tools
for documents, private configuration, credentials, databases, and full-system
recovery. Unsupported or hostile input is refused before mutation. URL
credentials are stripped from state and output. Pinned plugin/theme commits,
library/item identity, and applied provenance remain exact.

Architecture, formats, workflows, and evidence start at the
[documentation index](docs/index.md). Behavior changes use [OpenSpec](openspec/).

## Development

```bash
./tests/run.sh
./tests/mutate.sh
./tests/check-structure.sh .
openspec validate --all --strict
```

Automated tests use sandboxed command doubles. Real package effects, Git
authentication, clean-machine lifecycle, and rendered keyboard behavior are
recorded separately in [fresh-machine validation](docs/testing/fresh-machine-validation.md).

## License

MIT. See [LICENSE](LICENSE).
