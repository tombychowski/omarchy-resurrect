# Share and apply a loadout

A Montage loadout repository is a user-owned Git library. Each
`loadouts/<stable-id>/profile.json` is portable authored content. Applying one
creates separate private desired state on the current machine; it does not turn
the library into a cleanup registry. Read [Loadout profile](../contracts/loadout-profile.md)
and [Applied-loadout registry](../contracts/loadout-registry.md) for the exact
boundaries.

## Create and configure a library

```bash
mntg repository init loadouts "$HOME/.local/share/montage/loadouts" --id personal-loadouts
mntg repository configure personal "$HOME/.local/share/montage/loadouts" loadouts \
  --remote https://github.com/example/personal-loadouts
mntg repository list
```

The configured name `personal` is local convenience. `personal-loadouts` is
the stable repository identity stored in `montage.json`. Neither is a display
name for an individual loadout.

## Share one selected item

Capture all representable resources into a stable item:

```bash
mntg share --repository personal --loadout workstation \
  --name "My workstation" --description "Daily tools and integrations"
```

Or inspect the catalog and compose a non-empty subset:

```bash
mntg share catalog --json --repository personal --loadout minimal
mntg share --custom --repository personal --loadout minimal \
  --name "Small setup" \
  --select package:fd \
  --select webapp:Draw \
  --select theme-install:nord
```

The CLI reinspects selections before publication. More than one theme, unknown
or stale identities, malformed current content, and unsafe URLs are refused
without changing the selected item, its siblings, the index, or history. When
a previously selected resource becomes unavailable, use only the exact id and
fingerprint returned by the refreshed catalog:

```bash
mntg share --custom --repository personal --loadout minimal \
  --select package:fd \
  --acknowledge-unavailable plugin:old <catalog-fingerprint>
```

Review the resulting item and commit before publishing:

```bash
mntg repository loadouts personal
mntg repository loadout show personal workstation
git -C "$HOME/.local/share/montage/loadouts" show --stat HEAD
mntg repository sync personal
mntg repository sync personal --push
```

Generated instructions use a canonical credential-free URL and always include
the stable selector. Montage does not generate or resolve Ress short links.
See [Synchronize repositories](repository-sync.md) for transport credentials,
divergence, and the no-force guarantee.

## Preview and apply a library item

Always preview the exact selection first:

```bash
mntg apply https://github.com/example/personal-loadouts \
  --loadout workstation --dry-run
```

The preview lists installation, protection, sharing, conflict, refusal, and
theme actions. It cannot touch dotfiles, execute a profile script, remove
unrelated state, or read arbitrary home content.

Apply the same repository and selector:

```bash
mntg apply https://github.com/example/personal-loadouts --loadout workstation
```

The repository is resolved to one commit before preview; confirmation applies
that validated snapshot even if a mutable branch later moves. AUR packages
remain a separate decision:

```bash
mntg apply https://github.com/example/personal-loadouts \
  --loadout workstation --yes --aur
```

Use `--review-aur` for the helper review flow or `--no-aur` to defer builds.
Pinned plugins and Git themes use the commit in the profile. Unpinned fetched
code is skipped unless `--allow-unpinned` is explicitly supplied.

A contained standalone profile remains portable:

```bash
mntg apply /path/to/profile.json --dry-run
```

It has no repository id, stable item id, or commit provenance.

## Inspect machine-local applied state

```bash
mntg loadout list
mntg loadout list --json --contents
mntg loadout show LOCAL_ID --contents
mntg resource show package:ripgrep
mntg loadout check LOCAL_ID --json
```

These commands read the private registry under the Montage state root, not the
loadout library. For repository sources, show includes repository id, stable
item id, resolved commit, digest, and stored normalized snapshot without
refetching. Resource queries distinguish pre-existing protected resources from
ones introduced by Montage and list current claimants. Read-only checks never
repair or rewrite state.

## Update and repair

Repair addresses drift against the stored snapshot:

```bash
mntg loadout repair LOCAL_ID --dry-run
mntg loadout repair LOCAL_ID
```

It targets only missing safely restorable claims and preserves original cleanup
policy. AUR consent remains separate.

If the same repository item resolves to changed profile content, ordinary
apply refuses silent replacement. Update is explicit:

```bash
mntg loadout update LOCAL_ID --dry-run
mntg loadout update LOCAL_ID
```

Update re-resolves the same repository and stable item identity, then previews
retained, added, conflicting, and withdrawn claims. Supplying another source is
allowed only when it validates to those same immutable identities. Withdrawals
use the removal preservation planner.

## Remove applied state

```bash
mntg loadout remove LOCAL_ID --dry-run
mntg loadout remove LOCAL_ID
```

Removal releases shared claims, retains pre-existing resources, and deletes an
exclusive Montage-introduced resource only when current evidence still matches.
Changed or unverifiable resources require an explicit keep/remove decision.
Dependency refusal or cleanup failure leaves the operation resumable. Removing
applied state never deletes the authored library item or its Git history, and
removing a library configuration never removes applied state.
