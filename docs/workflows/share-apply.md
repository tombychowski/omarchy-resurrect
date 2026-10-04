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

## Re-export and update

Run `ress share` again to regenerate and commit changed profile content. Review the diff before pushing:

```bash
git -C ~/.local/share/ress/profile diff HEAD~1
git -C ~/.local/share/ress/profile push
```

Applying a loadout is additive. It does not keep another machine synchronized, and removing an item from a later profile does not remove it from machines that applied an earlier version.
