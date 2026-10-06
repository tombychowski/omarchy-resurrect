# CLI consumer protocol

The CLI exposes two machine-readable surfaces:

- `--porcelain` streams operation records for long-running commands and the panel.
- `--json` returns one JSON document for commands that advertise JSON output.

Consumers must select one of these surfaces instead of parsing human output. The `cli-consumer-protocol` OpenSpec capability owns the observable guarantees.

## General rules

- Machine-readable data is written to standard output.
- In porcelain mode, stdout contains protocol records only—no colors, headings, or explanatory prose.
- A JSON command writes one parseable JSON value to stdout, not a sequence of fragments.
- Exit status remains meaningful. Parseable output does not imply success; for example, verification and scanning return structured findings and exit non-zero when findings exist.
- Human mode is not stable protocol. Its wording and layout can improve without a compatibility event.
- Consumers must tolerate fields they do not use and must not infer new actions from unknown data.

## Porcelain records

Porcelain is line-oriented. Each record starts with an uppercase record type followed by pipe-separated fields.

```text
BEGIN|<action>|<target>
STEP|<category>|<state>|<message>
PROGRESS|<category>|<done>|<total>
LOG|<message>
DONE|<state>|<message>
```

### `BEGIN`

Marks the start of an operation after prerequisite validation and preparation.

- `action` is the command action such as `backup`, `restore`, or `share`.
- `target` is the relevant vault or output path.

Consumers should clear prior operation state when launching a command rather than require `BEGIN` to be the first possible process output; an early validation failure can terminate before normal operation setup.

### `STEP`

Reports a category or named operation step.

Defined states are:

- `start` — the step began;
- `ok` — the step completed successfully;
- `skip` — the step was not selected, was already complete, or was deliberately deferred;
- `warn` — the step completed or continued with an important qualification; and
- `fail` — the step failed.

The message is displayable context, not another protocol to parse. Because paths or commands can contain `|`, consumers should split the first three separators and preserve the remainder as the message. `Model.parseRecord` follows this rule.

### `PROGRESS`

Reports numeric progress within a category. `done` and `total` are numbers. When total is not useful, a consumer may present indeterminate progress from surrounding `STEP` state rather than invent a percentage.

### `LOG`

Carries a human-readable operation note inside the protocol. Consumers may show it in an activity log. Messages can include preview facts and deferred-work summaries.

### `DONE`

Terminates the protocol operation when the command reaches its normal terminal reporting path.

Current states include:

- `ok` — no recorded category failure;
- `partial` — restore completed its loop with one or more failed steps; and
- `fail` — the operation was stopped by a terminal failure such as a blocking secret scan.

Consumers must also handle process exit without a `DONE` record, because argument, dependency, or early validation errors can terminate before the operation protocol begins. In that case, stderr and exit status provide the failure context.

## JSON commands

### `ress status --json`

Status always attempts to return the current configured view, using safe fallback values for malformed hand-edited state.

```json
{
  "hasVault": true,
  "vault": "/home/user/.local/share/ress/vault",
  "remote": "https://github.com/user/private-vault",
  "lastBackup": 1791043200,
  "commits": 3,
  "unpushed": 0,
  "autoBackup": false,
  "intervalHours": 24,
  "categories": {
    "packages": true,
    "config": true,
    "omarchy": true,
    "webapps": true,
    "plugins": true,
    "secrets": false
  },
  "settings": {
    "aur": "ask",
    "enableUnits": "ask",
    "secretScan": "warn",
    "captureAutostart": false
  },
  "manifest": null
}
```

`manifest` is the parsed vault manifest when readable, otherwise `null`. Malformed boolean-like values fall back safely, malformed timestamps and counts become safe numbers, and a malformed manifest does not erase the surrounding status object. `hasVault` reflects recognition of a supported manifest path, not successful parsing of every manifest field.

### `ress verify --json`

Verification compares reconstructible vault entries with the current machine:

```json
{
  "vault": "/path/to/vault",
  "complete": false,
  "takenAt": "2026-10-03T12:00:00Z",
  "takenFrom": "source-host",
  "categories": {
    "packages": {
      "want": 2,
      "have": 1,
      "missing": ["example-bin"],
      "refused": []
    }
  }
}
```

Current category keys are `packages`, `config`, `themes`, `webapps`, `plugins`, and `services`. Every category value contains numeric `want` and `have` counts plus `missing` and `refused` arrays.

`refused` contains inventory that restore cannot safely reconstruct; it is distinct from `missing`. Array encoding preserves one logical entry even when its display name contains spaces.

Exit status is zero when `complete` is true and non-zero when restorable entries are missing or differ. Refused inventory is reported but is not counted as missing restorable work.

### `ress scan --json`

Credential scanning returns:

```json
{
  "findings": [
    {"file": "home/.config/example", "rule": "github-token"}
  ],
  "count": 1
}
```

The matched secret is never present. The scan covers all captured plaintext
below the vault root while excluding `.git` and
`secrets/secrets.tar.age`. Exit status is zero for no findings and non-zero
when one or more findings exist.

### Applied-loadout JSON

`ress loadout list --json` emits one object with a `loadouts` array. Each item includes stable local `id`, display metadata, sanitized `source`, digest, timestamps, precedence, lifecycle `state`, `resourceCount`, and `attentionCount`. The stored normalized profile is omitted unless `--contents` is present.

`ress loadout show ID --json` emits `{loadout, claims, resources}` for one local identity. `--contents` includes `loadout.profile`; otherwise executable-shaped remote references remain hidden from the ordinary inventory.

`ress resource list --json` emits `{resources:[...]}` and accepts `--state STATE`. `ress resource show RESOURCE-ID --json` emits one resource with `firstObserved`, `cleanupPolicy`, recorded state/evidence, and `claimants`, the local loadout ids related through claims.

`ress loadout check [ID] --json` performs live inspection and emits:

```json
{
  "healthy": false,
  "loadouts": [{
    "id": "work-a1b2c3d4e5f6",
    "attentionCount": 1,
    "resources": [{
      "id": "package:example",
      "claimStatus": "healthy",
      "healthState": "missing",
      "currentState": "missing",
      "currentEvidence": {}
    }]
  }]
}
```

`healthState` is the consumer-facing classification. It reports protected resources explicitly and folds deferred or removal-pending claims into `pending`; `currentState` remains the direct machine observation. Its exit status is non-zero when any selected resource is not currently satisfied. Inspection does not repair or update the registry.

`ress status --json` additionally contains `loadouts:{available,count,attention}`. A missing registry is an available empty inventory. A malformed or unsupported registry produces `available:false` and null counts without erasing valid backup status.

Loadout mutations use the same porcelain record grammar as restore. A fully healthy apply ends with `DONE|ok|...`; deferred, failed, conflicting, or uncertain work ends with `DONE|partial|...` and a non-zero status. Consumers must not reinterpret warning prose as success.

### `ress share catalog --json [--out DIR]`

The share catalog is the complete local discovery boundary for a loadout
composer. It returns exactly one schema-versioned object. `--out` selects which
current exported profile is compared; it does not change any files.

```json
{
  "schemaVersion": 1,
  "resources": [{
    "id": "package:fd",
    "kind": "package",
    "name": "fd",
    "shareable": true,
    "reasonCode": "",
    "reason": "",
    "channels": ["native"],
    "active": false
  }],
  "currentExport": {
    "state": "valid",
    "name": "Small setup",
    "description": "Tools I use",
    "resourceIds": ["package:fd"],
    "unavailable": [{
      "id": "plugin:old",
      "kind": "plugin",
      "name": "old",
      "reasonCode": "missing",
      "reason": "resource is not present on this machine",
      "fingerprint": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    }]
  },
  "presets": {
    "state": "valid",
    "loadouts": [{
      "id": "work-a1b2c3",
      "name": "Work",
      "resourceIds": ["package:fd"],
      "warnings": [{"id": "plugin:old", "state": "missing"}]
    }]
  },
  "counts": {"package": 1},
  "limits": {"themes": 1}
}
```

Resource kinds are `package`, `plugin`, `webapp`, and `theme`. Stable
shareable identities are `package:<name>`, `plugin:<id>`, `webapp:<name>`, and
`theme-install:<name>`. An item without a safe logical identity receives an
opaque `unavailable:<kind>:<digest>` identity only so the panel can explain it;
that identity can never be selected. Package `channels` contains `native`,
`aur`, or both. `active` is meaningful for theme presentation.

Candidate refusal codes are bounded to `missing-manifest`, `unsafe-id`,
`missing-remote`, `unsafe-remote`, `unpinned`, `unsupported-launcher`,
`credential-url`, `unsafe-name`, `unsafe-icon`, `local-only`, and `missing-theme`. A valid current
export can additionally report `missing` or `definition-mismatch`. An invalid
current profile uses state `unavailable` with `invalid-profile`; no profile uses
state `absent`. Applied presets independently use `valid` or `unavailable`,
with `invalid-registry` for malformed local state. Preset warning states are
live resource or claim classifications and are display information, not
deletion authority.

Unavailable current-export fingerprints bind the stable identity to the
canonical prior profile definition. They are staleness tokens used by selective
export, not secrets or general authorization.

Selective porcelain export emits `BEGIN|share|<output>` and the normal Share
step records. Success ends with `DONE|ok|<output>`. A selected identity that is
missing or no longer shareable, an acknowledgement-required withdrawal, a stale
fingerprint, invalid metadata, or a cardinality violation ends non-zero with
`DONE|fail|<reason>`; the reason names the affected logical identity when one is
known. Explanatory prose remains on stderr, never mixed into stdout.

The catalog intentionally omits resource definitions, commands, file content,
URL credentials, registry cleanup policy, ownership evidence, and claims. It
does not perform network discovery. Optional current-export and preset failures
do not erase an otherwise valid machine inventory.

## stderr and failures

Consumers should collect stderr separately. Porcelain/JSON stdout must remain parseable, but an early `die` path can explain invalid usage, missing dependencies, unsafe input, or an unavailable vault through stderr and non-zero exit.

The panel turns worker stderr or a non-zero exit without a message into an operation error. Status JSON parse failure results in no accepted status object; the panel must not derive substitute vault facts on its own.

## Compatibility expectations

Within a supported schema generation:

- record type names and field ordering are stable;
- JSON keys documented above retain their meaning and value type;
- new optional JSON fields or new display-only protocol messages may be added;
- consumers ignore unknown records or fields they do not understand;
- consumers do not parse message prose to make safety decisions; and
- behavior changes to required records, field meaning, or types require an OpenSpec and contract update with consumer tests.

Protocol tests live in `tests/cases/12-porcelain.sh`, `28-tracked-apply.sh`, and
`40-share-compose.sh`; JSON behavior in `tests/cases/08-verify.sh`,
`19-status-config.sh`, `27-loadout-query.sh`, `29-loadout-check.sh`, and
`40-share-compose.sh`; parser behavior lives in `tests/model-test.js`.
