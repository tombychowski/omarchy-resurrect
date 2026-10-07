# Loadout profile

A loadout is a portable, inspectable description of supported setup actions.
It is not a backup. The format can name packages, pinned plugins,
reconstructible web apps, and one theme; it has no field for dotfiles,
arbitrary files, secrets, commands, repository identity, or cleanup authority.

`mntg share` writes a profile into one explicitly selected library item.
`mntg apply` validates, previews, confirms, and performs the supported actions.
The `loadout-sharing` OpenSpec capability owns the observable guarantees.

## Library layout and stable selection

A native loadout repository has the shared root `montage.json` envelope and
stores zero or more independent items:

```text
montage.json
loadouts/
  workstation/
    profile.json
    README.md
  minimal/
    profile.json
    README.md
.git/
```

The bounded directory name is the stable loadout id. Renaming display metadata
inside `profile.json` does not change that id or path. Every portable leaf is
therefore addressed as `loadouts/<stable-id>/profile.json`. The repository
envelope is defined by [Repository format](repository-format.md); it is not
copied into the portable leaf.

Initialize, configure, inspect, and select a library explicitly:

```bash
mntg repository init loadouts "$HOME/.local/share/montage/loadouts" --id personal-loadouts
mntg repository configure personal "$HOME/.local/share/montage/loadouts" loadouts \
  --remote https://github.com/example/personal-loadouts
mntg repository loadouts personal
mntg repository loadout show personal workstation
```

## Current portable schema

The leaf remains schema version `1` with `kind: "omarchy-loadout"`:

```json
{
  "schemaVersion": 1,
  "kind": "omarchy-loadout",
  "name": "Example setup",
  "author": "Example user",
  "description": "A short human description",
  "createdAt": "2026-10-03T12:00:00Z",
  "omarchy": "version-or-unknown",
  "packages": {"native": ["fd", "ripgrep"], "aur": ["example-bin"]},
  "plugins": [{
    "id": "example.widget",
    "url": "https://github.com/example/widget",
    "commit": "0123456789abcdef0123456789abcdef01234567"
  }],
  "webapps": [{"name": "Example", "url": "https://example.com/", "icon": "example"}],
  "theme": {
    "name": "example-theme",
    "url": "https://github.com/example/theme",
    "commit": "89abcdef0123456789abcdef0123456789abcdef"
  }
}
```

Unknown input fields do not grant behavior. A normalized leaf stored by
Montage has the exact fields above. The item remains usable as a contained
standalone `profile.json` without a Montage envelope; repository identity and
Git history are available only when the repository source and stable selector
are supplied.

## Sharing

Unfiltered sharing captures every currently representable package, plugin, web
app, and active shareable theme into one selected item:

```bash
mntg share --repository personal --loadout workstation \
  --name "My workstation" --description "Daily tools"
```

Selective sharing starts with the CLI-owned catalog and submits only stable
resource identities:

```bash
mntg share catalog --json --repository personal --loadout minimal
mntg share --custom --repository personal --loadout minimal \
  --name "Small setup" --description "Only the essentials" \
  --select package:fd \
  --select plugin:example.widget \
  --select theme-install:nord
```

The selection must be non-empty, unique, currently shareable, and contain at
most one theme. Names contain 1–120 display-safe characters and descriptions
at most 1,000. Montage reinspects every selection while holding the repository
lock, renders the complete item in same-filesystem staging, validates it,
atomically replaces only `loadouts/<stable-id>`, and creates one commit only
when repository content changes. Sibling items are untouched.

A missing, unsafe, or definition-mismatched resource from the selected current
item stays visible until the caller supplies the exact catalog fingerprint:

```bash
mntg share --custom --repository personal --loadout minimal \
  --select package:fd \
  --acknowledge-unavailable plugin:old <catalog-fingerprint>
```

Stale selections, stale acknowledgements, malformed current leaves, and
credential-bearing web-app URLs fail before publication. Git URL user
information is removed before a remote, profile, README, config record, or
terminal instruction is persisted or displayed.

## Applying

A native repository source always names the stable item explicitly:

```bash
mntg apply https://github.com/example/personal-loadouts --loadout workstation --dry-run
mntg apply https://github.com/example/personal-loadouts --loadout workstation
```

Configured local repositories may use their selector in place of the URL:

```bash
mntg apply personal --loadout workstation --dry-run
```

Montage resolves the source to one exact commit before preview, materializes
that commit in isolation, validates the repository envelope and selected
contained regular `profile.json`, and uses only that snapshot for the plan and
confirmation. A canonical URL, repository id, stable loadout id, resolved
commit, normalized profile digest, and validated profile snapshot are stored
after confirmation. Ordinary apply refuses changed content for the same
repository/item identity; `mntg loadout update LOCAL_ID` is the explicit
previewed replacement path.

A local `profile.json`, its containing directory, or an HTTPS JSON profile URL
remains supported as a standalone portable leaf. Standalone input has no
repository or commit identity. Ress short links are not native Montage sources;
they enter only through the explicit Ress port workflow.

## Validation and consent

Before planning, Montage requires valid JSON, exact kind, and a plain supported
integer schema version. Package names, integration ids, labels, URLs, and
commits are independently bounded before reaching external commands. URL user
information never enters desired state. Human metadata is stripped of terminal
control characters.

Apply lists packages, AUR builds, plugins, web apps, and theme actions and
states that dotfiles and arbitrary scripts are outside the operation. `--dry-run`
does not mutate or track. A live apply requires confirmation, and AUR execution
remains a separate consent decision. Plugin and Git-theme code is checked out
at its recorded commit unless the user explicitly accepts `--allow-unpinned`.

## Library items versus applied state

A library item is portable authored content in a user-owned Git repository.
An applied loadout is private machine-local desired state under the Montage
state root. Confirmation records local resource observations, claims, outcomes,
cleanup policy, source provenance, and an offline profile snapshot; none of
those fields is written back into `profile.json` or copied to another machine.

Apply is additive. Deletion is available only through the separately previewed
`mntg loadout remove LOCAL_ID` workflow. See
[Applied-loadout registry](loadout-registry.md) and
[Share and apply](../workflows/share-apply.md).
