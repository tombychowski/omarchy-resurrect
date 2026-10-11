# Ress loadout migration architecture

Montage no longer has a general adapter or bidirectional port framework. The
only foreign boundary is the frozen Ress v1 portable-loadout migration owned by
two literal modules:

```text
bin/mntg
  ├─ port/commands.sh   exact `port ress inspect|import loadout` parsing
  └─ port/ress.sh       discovery, validation, result, decisions, staging
             │
             └─ loadout repository lock / journal / commit primitives
```

`bin/mntg` sources both files literally. User-controlled format or callback
text never selects a file or function. `ress` is the only accepted format id;
there is no `ress-v1` alias, future-format registry, dynamic callback matrix,
export direction, vault translation, or history traversal.

## Trust boundary

The migration reader accepts only a regular, non-symlink `profile.json`
contained by the supplied regular directory, or that file itself. It validates
JSON, integer schema 1, the exact declarative profile shape, bounded names,
unique resources, public credential-free URLs, and commit pins using native
profile validation. It opens no other source file. Sidecar content can produce
only a bounded ignored-content warning.

The source and destination remain separate authorities:

- Ress config, Git remotes, locks, operational state, claims, cleanup policy,
  credentials, keys, and machine identity are never imported.
- The destination is one configured loadout repository and one new stable id.
- Preview is local and non-mutating.
- Live import revalidates the source digest and profile after confirmation.
- Publication uses the native repository identity lock, recovery journal,
  same-filesystem stage, native leaf validator, and content-sensitive commit.
- Applying the imported item later—not migration—creates local provenance and
  cleanup authority from current machine observation.

## Decision and result ownership

`port/ress.sh` builds the same versioned
`montage-ress-loadout-migration` decision object for inspection, dry run, and
live import. Ress and Montage self-plugin entries are reported separately and
require `include` or `omit` when present. Safety or authority failures are
refusals and cannot be converted into accepted loss.

Human, JSON, and porcelain views are projections of that object. Consumers do
not inspect the source, invoke Git, or infer destination mutations themselves.
A future foreign format or reverse conversion requires a new product decision
and OpenSpec change rather than extension of an unused framework.
