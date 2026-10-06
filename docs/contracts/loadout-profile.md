# Loadout profile

A loadout is a shareable, inspectable description of supported setup actions. It is not a backup. The format can name packages, pinned plugins, reconstructible web apps, and a theme; it has no field for dotfiles, arbitrary files, secrets, or commands.

`ress share` writes the profile. `ress apply` validates, previews, confirms, and performs its supported actions. The `loadout-sharing` OpenSpec capability owns the observable guarantees.

## Repository layout

The default export is a small Git repository at `~/.local/share/ress/profile`:

```text
profile.json
README.md
.git/
```

`--out DIR` selects another export location. Updating an existing export commits changed generated content. The generated README explains how to apply the profile but is not parsed as an instruction.

## Current schema

The current profile has `schemaVersion: 1` and `kind: "omarchy-loadout"`.

```json
{
  "schemaVersion": 1,
  "kind": "omarchy-loadout",
  "name": "Example setup",
  "author": "Example user",
  "description": "A short human description",
  "createdAt": "2026-10-03T12:00:00Z",
  "omarchy": "version-or-unknown",
  "packages": {
    "native": ["fd", "ripgrep"],
    "aur": ["example-bin"]
  },
  "plugins": [
    {
      "id": "example.widget",
      "url": "https://github.com/example/widget",
      "commit": "0123456789abcdef0123456789abcdef01234567"
    }
  ],
  "webapps": [
    {
      "name": "Example",
      "url": "https://example.com/",
      "icon": "example"
    }
  ],
  "theme": {
    "name": "example-theme",
    "url": "https://github.com/example/theme",
    "commit": "89abcdef0123456789abcdef0123456789abcdef"
  }
}
```

Unknown fields do not grant new behavior. Apply reads only the fixed supported fields above.

## Export semantics

`ress share` derives data from the current machine rather than copying vault payloads:

- explicit native and foreign package names come from the package database;
- plugins include a safe HTTPS remote and valid exact commit;
- web apps include only a name, HTTPS URL, and icon identifier that the profile can represent;
- the current theme includes its name and, when available and safe, its repository remote and commit.

The ordinary `ress share` invocation retains this whole-machine behavior: it
exports every shareable package, plugin, and web app plus the active shareable
theme. The profile still represents at most one theme.

HTTPS Git remotes are canonicalized without URL user information before they
enter candidates or profiles. Credential-bearing web-app URLs are not
canonicalized because that could change application semantics: local candidates
are unavailable and incoming profiles are refused before apply mutation.

Selective export uses the same collectors and schema:

```bash
ress share --custom \
  --name "Small setup" --description "Only the essentials" \
  --select package:fd \
  --select plugin:example.widget \
  --select theme-install:nord
```

`--custom` requires a non-empty set of unique, currently shareable logical
identities and allows no more than one theme. `--select` and
`--acknowledge-unavailable` are invalid without it. Names contain 1–120
display-safe characters; descriptions contain at most 1,000 display-safe
characters. Control characters are refused.

Before writing, selective export takes a lock scoped to the canonical output
directory, reinspects the current machine, validates the current profile and
metadata, resolves every selected identity to its current safe definition, and
renders the complete profile and README in a sibling temporary directory. A
validation refusal leaves the generated files, Git index/history and remote,
and configured `PROFILE_URL` unchanged. Existing Git and `--out` behavior is
otherwise retained.

If an entry in a valid current export is now missing, unsafe, or definition
mismatched, omission requires the exact catalog acknowledgement:

```bash
ress share --custom --select package:fd \
  --acknowledge-unavailable plugin:old <catalog-fingerprint>
```

The CLI rereads the current profile and compares both identity and fingerprint.
A changed or stale acknowledgement is refused. Deliberately deselecting a still
available resource requires no acknowledgement. A malformed current profile is
not treated as an empty export and cannot be selectively replaced.

Web-app launchers with browser flags, multiple executable entries,
credential-bearing URLs, or other unsupported forms are omitted and reported.
Local-only or unsafe Git remotes are not converted into fetchable code
references. No `$HOME` content is embedded.

`ress share catalog --json [--out DIR]` exposes safe identities and omission
reasons for composition without exposing the definitions themselves. Its exact
shape and confidentiality boundary are defined in the
[CLI protocol](cli-protocol.md). Applied loadouts may seed identities only when
their stored definitions match healthy current resources; their metadata,
ownership, cleanup policy, and claims never enter the public profile.

## Accepted sources

`ress apply SOURCE` accepts:

- a local `profile.json` file;
- a local directory containing `profile.json`;
- an HTTPS JSON URL;
- an HTTPS Git repository whose root contains `profile.json`;
- the supported `ress.sh/gh/<user>/<repo>` shorthand; and
- normalized GitHub host/repository forms accepted by the CLI.

The ress shorthand is expanded locally to the canonical GitHub URL before a network request. ress does not upload the profile to or fetch profile content through the shortener.

## Validation

Before applying actions, ress requires valid JSON, the exact loadout kind, and a plain supported integer schema version. Future or malformed schema versions are refused.

Every value that can reach an external command is independently constrained:

- package names use the package-name grammar and cannot begin with option syntax;
- plugin ids, theme names, and icon ids use bounded safe identifier grammars;
- display labels exclude control and command syntax;
- network sources must be safe HTTPS URLs;
- pinned commits are full lowercase Git object ids in the supported form.

Human-controlled title, author, description, and creation fields are stripped of terminal control characters before display.

Invalid entries are refused or omitted without granting broader interpretation to the remaining JSON.

## Preview and confirmation

Apply computes only actions missing from the current machine, then presents:

- repository packages to install;
- AUR packages to build, identified as a separate consent boundary;
- plugins to clone;
- web apps to create; and
- a theme to clone or select.

The preview also states that apply will not remove anything, touch dotfiles, run a script from the profile, or read outside those supported actions.

`--dry-run` stops after the complete plan. A live apply requires confirmation unless `--yes` was supplied. The AUR decision remains independent: `--yes` alone does not authorize PKGBUILD execution.

## Pinning and code

Plugin repositories and cloneable Git themes are installed at the exact commit recorded in the profile, with a detached checkout. An entry without a valid commit is skipped by default.

`--allow-unpinned` is an explicit exception that permits a branch head for an otherwise valid repository. It is not implied by confirmation or `--yes`.

A theme name without a cloneable repository can still select a bundled or already installed theme; it cannot cause an unpinned repository to be cloned by default.

## Additive behavior

Apply normalizes the supported fields, computes a canonical digest, compares every represented resource with current machine and registry state, and operates only on eligible missing entries. Unknown fields and object ordering do not create a different local identity. Invalid supported entries are reported and omitted.

A confirmed apply stores the normalized version-1 profile as machine-local desired state, including an all-present no-op profile. This does not change the public schema: registry identity, provenance, outcomes, and cleanup policy are local facts and are never written into `profile.json`.

An exact digest reapplication reconciles the existing local loadout. If a known sanitized source now returns different normalized content, ordinary apply refuses silent replacement. The user runs `ress loadout update ID [SOURCE]` to preview retained, added, conflicting, and withdrawn claims. Update routes withdrawals through the same preservation planner as removal.

Apply itself remains additive. It has no package-removal action and no representation for deleting user files. Failed plugin clones are cleaned from their intended plugin target, but unrelated installed plugins and themes remain untouched. Deletion is available only through the separately previewed, confirmed `ress loadout remove ID` workflow described in [Restore safety](restore-safety.md).

See [Applied-loadout registry](loadout-registry.md) for local state and [Share and apply](../workflows/share-apply.md) for the lifecycle.
