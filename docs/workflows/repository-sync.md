# Synchronize Montage repositories

Montage repositories are ordinary local Git repositories with a validated
`montage.json` identity. A configured remote is optional. The CLI provides a
conservative synchronization boundary for loadout libraries; it never treats a
remote as authority merely because a fetch succeeds.

## Configure transport, not credentials

Configure a credential-free HTTPS, SSH, or Git transport URL:

```bash
mntg repository configure personal "$HOME/.local/share/montage/loadouts" \
  --remote https://github.com/example/personal-loadouts
```

Authentication belongs to Git's credential helper, an SSH agent, or another
user-controlled transport mechanism. Do not put a username, password, access
token, private key, or credential-helper output in Montage configuration,
repository files, commands, or generated instructions. Montage rejects or
redacts URL user information before persistence and output. Loadout libraries
are designed to be shareable and may be public.

## Inspect before changing history

Fetch and classify without changing the current branch, index, or working tree:

```bash
mntg repository sync personal
mntg repository sync personal --json
```

The result is one of `equal`, `local-ahead`, `remote-ahead`, `divergent`, or an
explicit fetch/refusal failure. The result includes stable repository identity,
the fixed loadout-library kind, exact local and fetched commits, and
ahead/behind counts. Fetch writes only a Montage-owned observation ref.

## Perform one history-preserving action

After reviewing the classification, request exactly one direction:

```bash
mntg repository sync personal --pull
mntg repository sync personal --push
```

Pull is accepted only when the fetched history is ahead of the local commit,
the exact fetched tree passes the loadout-library validator, and Git can
fast-forward a clean unchanged worktree. Push uses an ordinary non-forced Git
push only when local history is ahead and unchanged after preview. Equal history
is a successful no-op.

Divergence is always decision-required. Montage does not reset a branch,
automatically merge repository content, rebase, delete remote history, or
force-push. Inspect both histories with Git, decide deliberately which history
to preserve, and perform any reconciliation outside Montage. Then run the
fetch-only preview again before asking Montage to pull or push.

A failed fetch, validation, fast-forward, or push is reported as failure rather
than partial success. Local content and both known histories remain available
for inspection.
