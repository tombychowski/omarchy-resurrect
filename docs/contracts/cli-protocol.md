# CLI consumer protocol

Commands advertising `--json` emit exactly one schema-versioned JSON object.
`--porcelain` emits only newline-delimited records. Human output is not a
protocol. Exit status remains meaningful even when a safe refusal object is
available.

All current JSON objects use integer `schemaVersion: 1` and a `kind` beginning
`montage-`. Consumers ignore fields they do not use but reject wrong types,
unknown schema versions, and malformed required relations. They never parse
human prose to authorize an action.

Any command that first migrates configured libraries reports the migration in
its normal result. JSON Share catalogs, repository item/catalog results, and
Ress import reports carry `migration`; ordinary apply, update, and Share output
prints the notice or emits `MIGRATION` in porcelain mode. No notice is inserted
outside the JSON document. Subsequent reads report a no-op where applicable.

`loadout check --json` exits 0 for healthy state and 1 for a valid unhealthy
result. Consumers retain validated unhealthy details; other failures and
malformed output remain unavailable. Doctor accepts existing writable regular
configuration files and writable nonsymlink state directories.

## Porcelain

Shared records are:

```text
BEGIN|<action>|...
STEP|<category>|<start|ok|skip|warn|fail>|<message>
LOG|<message>
DONE|<ok|partial|fail>|<message>
```

Messages may contain `|`; parsers preserve everything after the fixed fields.
An early validation failure may exit before `BEGIN` or `DONE`, so consumers also
capture stderr and exit status.

Status emits:

```text
BEGIN|status|1
MIGRATION|1|<performed>|<prior-schema>|<new-schema>|<retired-names>|<rollback-copy>
STATUS|1|<attention>|<applied-count>|<library-count>
DONE|ok|status complete
```

The migration record is also present as `migration` in JSON results. Its
`retiredVaults` and `backup` field names describe the one-time legacy
configured-registry migration; they are not active repository kinds.

Repository sync emits
`SYNC|1|<relationship>|<ahead>|<behind>|<fetch-ok>|<performed>|<action-ok>|<reason>`.
Ress migration emits `RESS|1|<operation>|<compatible>|<ready>|<published>|<reason>`
plus zero or more `RESS_LOSS|<code>|<decision>|<waivable>` records.

## Status JSON

`mntg status --json` returns one `montage-status` object:

```json
{
  "schemaVersion": 1,
  "kind": "montage-status",
  "attention": "repair-needed",
  "causes": ["repair-needed", "update-available"],
  "operation": {"active": false, "valid": true, "ownerPid": null},
  "loadouts": {
    "available": true,
    "evidenceValid": true,
    "count": 1,
    "attention": 1,
    "repairNeeded": 1,
    "drifted": 0,
    "partialOrFailed": 0,
    "updateAvailable": 1,
    "items": []
  },
  "repositories": {
    "available": true,
    "count": 1,
    "attention": 0,
    "items": [],
    "migration": null
  },
  "settings": {"aur": "ask"},
  "migration": null
}
```

The stable `attention` vocabulary, in descending precedence, is:

1. `operation-active`;
2. `operation-partial-or-failed`;
3. `unavailable-or-invalid`;
4. `repository-attention`;
5. `drifted`;
6. `repair-needed`;
7. `update-available`;
8. `healthy`.

`causes` preserves all simultaneous details. Missing registries are valid empty
state. A present malformed applied, configured-library, operation, or advisory
evidence file is unavailable rather than empty. `update-available` requires
evidence recorded by an explicit update preview for the same local loadout,
repository, item, and baseline commit. Ordinary status performs no fetch,
synchronization, repair, apply, update, or state write. Cached sync refs may
establish remote-ahead or divergent library attention.

## Libraries

Repository list/show/validation objects carry configured name, canonical path,
fixed `type:"loadouts"`, stable repository id, credential-free remote,
validity, status, and migration facts. `montage-loadout-catalog` binds every
stable item id and digest to one repository id and current exact commit.

`montage-repository-sync` contains repository id, `repositoryType:"loadouts"`,
exact local and fetched commits, relationship, ahead/behind counts, fetch
status, and any requested action. Relationships are `equal`, `local-ahead`,
`remote-ahead`, or `divergent`; bounded failure statuses describe invalid or
unavailable evidence. Pull is fast-forward-only, push is non-forced, and
divergence returns decision-required.

## Applied loadouts and resources

`mntg loadout list --json` emits `montage-applied-loadout-list`. Items include
stable local id, display metadata, credential-free source, exact optional
library/item/commit provenance, normalized digest, lifecycle state,
`resourceCount`, and `attentionCount`. `--contents` adds the stored normalized
profile.

`mntg loadout check [ID] --json` emits `montage-loadout-check` with live
resource rows. Each row retains recorded claim state and direct `currentState`,
plus consumer-facing `healthState`. Check does not mutate or implicitly repair.

Resource list/show results retain definition, first observation, cleanup policy,
recorded evidence, live health, and claimant identities. These records explain
authority; they do not grant new authority.

Lifecycle mutations use shared porcelain records. Healthy completion ends in
`DONE|ok`; deferred, failed, conflicting, or uncertain work ends in
`DONE|partial` and a nonzero exit.

## Share catalog

`mntg share catalog --repository NAME --loadout ID --json` emits
`montage-share-catalog` with:

- stable candidate ids and kinds (`package`, `plugin`, `webapp`, `theme`);
- `shareable`, bounded refusal code/reason, package channels, and active theme;
- `currentItem`, containing the selected ids and fingerprinted unavailable
  definitions for the selected library item;
- applied-loadout starting presets with warning rows;
- counts and the single-theme limit.

The catalog omits commands, arbitrary file content, URL credentials, cleanup
policy, claims, and private authority. Selective Share accepts only catalog ids,
reinspects immediately before publication, and requires the matching
fingerprint to withdraw an unavailable prior definition.

An unavailable row uses a full lowercase SHA-256 definition fingerprint, for
example:

```json
{
  "id": "plugin:old",
  "state": "missing",
  "fingerprint": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
}
```

## Ress v1 migration

`mntg port ress inspect` and `mntg port ress import loadout` use one
`montage-ress-loadout-migration` object. It contains literal format `ress-v1`,
supported/source schema versions, contained source identity, optional selected
destination, compatibility, readiness, bounded warnings/losses, separate Ress
and Montage self-plugin decisions, and planned/published commit state.

An unsupported or hostile source returns the same object with
`compatible:false` when safe structured reporting is possible. Required but
unanswered self-plugin choices use `ready:false`. There is no general format
registry or reverse-conversion envelope.

## Compatibility

Within schema 1, documented record names, field types, and field order remain
stable. New optional JSON fields or ignorable records may be added. Required
meaning or type changes require an OpenSpec and consumer-test update.

Evidence lives in `68-loadout-protocol.sh`, `70-status-attention.sh`, repository,
Share, lifecycle, and Ress cases, plus `tests/model-test.js`.
