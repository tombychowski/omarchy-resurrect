# Share and apply a loadout

A loadout shares supported setup choices without sharing a home directory. Its fixed format contains packages, pinned plugins, reconstructible web apps, and a theme. Read [Loadout profile](../contracts/loadout-profile.md) for the exact schema and validation rules.

## Export a loadout

From the machine whose setup you want to share:

```bash
ress share --name "My Omarchy setup" --description "Tools and integrations I use"
```

The default output is `~/.local/share/ress/profile`. Choose another directory when needed:

```bash
ress share --out /tmp/my-loadout
```

Read the output warnings. A web app whose launcher form cannot be represented is left out rather than weakened into a misleading entry. Plugins and cloneable themes need a safe remote and exact commit to travel under the default pinning policy.

Inspect `profile.json` before publishing. It should contain no dotfiles, keys, arbitrary files, or command field.

## Publish

The export is a Git repository. Add a public remote and push it using your normal Git credentials:

```bash
cd ~/.local/share/ress/profile
git remote add origin git@github.com:you/my-omarchy-loadout.git
git push -u origin main
```

Share either the repository URL or the shorthand:

```text
https://github.com/you/my-omarchy-loadout
ress.sh/gh/you/my-omarchy-loadout
```

The shorthand is expanded to GitHub locally before any request. ress.sh does not store or proxy the profile.

## Preview another loadout

Always begin with a dry run:

```bash
ress apply ress.sh/gh/someone/their-loadout --dry-run
```

The preview identifies the profile and lists missing repository packages, AUR packages, plugins, web apps, and the theme action. It also states what apply cannot do: remove items, touch dotfiles, run profile scripts, or read arbitrary home content.

An invalid kind, schema, package name, identifier, URL, or commit is refused or omitted before action.

## Apply

Run the same source without `--dry-run`:

```bash
ress apply ress.sh/gh/someone/their-loadout
```

Apply asks for general confirmation. AUR packages are a separate decision because they build fetched PKGBUILDs:

```bash
ress apply ress.sh/gh/someone/their-loadout --yes --aur
```

Use `--review-aur` to retain the AUR helper's review flow or `--no-aur` to leave those packages unbuilt.

Pinned plugins and Git themes are checked out at the recorded commit. Entries without a commit are skipped by default. `--allow-unpinned` is an explicit exception that accepts a repository branch head; use it only after reviewing that additional trust decision.

A confirmed loadout receives a readable local id and remains visible even when some work is declined or fails. Successful no-op application is tracked too: resources that already existed are protected rather than adopted for future cleanup. Deferred AUR work, missing integrations, and conflicts produce a partial outcome instead of a false success.

## Inspect applied loadouts and resources

```bash
ress loadout list
ress loadout list --json --contents
ress loadout show LOCAL_ID --contents
ress resource show package:ripgrep
```

The resource view answers whether the resource pre-existed tracking or was introduced by ress, its cleanup policy and recorded evidence, and every loadout that currently claims it. The normalized profile snapshot remains available offline even if its source disappears.

Check live machine health without changing anything:

```bash
ress loadout check
ress loadout check LOCAL_ID --json
```

Missing, modified, conflicting, or unverifiable resources make check return non-zero. Status refresh and checking never reinstall them automatically.

## Repair drift

Repair is explicit and previewed:

```bash
ress loadout repair LOCAL_ID --dry-run
ress loadout repair LOCAL_ID
```

Repair uses the apply validators and pinning rules but only targets missing, safely restorable claims. AUR builds still need their independent `--aur`, `--review-aur`, or configured decision; `--yes` alone does not authorize them. Declined work remains pending for another repair.

## Re-export and update

Run `ress share` again to regenerate and commit changed profile content. Review the diff before pushing:

```bash
git -C ~/.local/share/ress/profile diff HEAD~1
git -C ~/.local/share/ress/profile push
```

Applying a loadout does not poll or continuously synchronize its source. An exact reapply reconciles the existing local identity. If content at a known source changes, ordinary apply refuses replacement; update it explicitly:

```bash
ress loadout update LOCAL_ID --dry-run
ress loadout update LOCAL_ID
ress loadout update LOCAL_ID https://github.com/you/alternate-source
```

The preview distinguishes retained, added, conflicting, and withdrawn claims. Withdrawn claims use the same retention/removal rules as loadout removal, so omission from a remote profile never becomes an unseen deletion.

## Remove an applied loadout

The user-facing inverse of apply is **remove loadout** (not “unapply”):

```bash
ress loadout remove LOCAL_ID --dry-run
ress loadout remove LOCAL_ID
```

The preview explains which exclusive ress-introduced resources can be deleted, which shared claims are merely released, which pre-existing resources stay, which are already absent, and which changes need a decision. For an externally changed exclusive resource, rerun with `--keep-modified` to leave it unmanaged or `--remove-modified` after reviewing the displayed evidence.

Removal does not delete application data, arbitrary configuration, dependencies, or unrelated state. Package dependency refusal and cleanup failure leave the loadout removal-pending so the same command can resume it. Theme removal first selects the newest remaining requested theme or the original baseline; a manual external theme choice is preserved.
