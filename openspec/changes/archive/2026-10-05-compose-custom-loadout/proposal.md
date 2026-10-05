# Proposal

## Why

`ress share` currently exports every representable resource it discovers, and the panel exposes that behavior as a single action without name or description inputs. Users need a simple way to keep the existing whole-machine export while also composing a loadout from an explicit, inspectable subset of the current machine.

## What Changes

- Add a CLI-owned share catalog that reports installed loadout candidates, stable resource identities, shareability or refusal reasons, the current exported profile, and reusable selections derived from applied loadouts.
- Let `ress share` accept an explicit set of catalog resource identities plus user-supplied name and description, reinspect those resources before export, and refuse stale or unavailable explicit selections rather than silently weakening the requested profile.
- Keep the existing schema-version-1 profile, single default profile repository, configured share URL, and unfiltered CLI export behavior compatible.
- Replace the panel's one-action Share surface with a keyboard-accessible composer whose explicit starting choices are all shareable resources, the current export, an empty selection, or one applied loadout; users may then add applied-loadout selections and individual current resources.
- Require zero-or-one theme selection, prevent empty exports, and require explicit acknowledgement before a previously exported resource that is now missing or unshareable is removed from the current profile.
- Continue to exclude dotfiles, secrets, arbitrary files, commands, package-owned launchers, unsupported web-app forms, and unpinned or unsafe code references, while making relevant omissions visible.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `loadout-sharing`: Define selective catalog-based export, current-profile reuse, explicit-selection validation, metadata handling, theme cardinality, and acknowledgement of unavailable previously exported resources.
- `cli-consumer-protocol`: Define the structured JSON catalog consumed by the panel and truthful protocol outcomes for selective export.
- `panel-integration`: Define the keyboard-accessible Share composer, explicit starting choices, additive applied-loadout presets, metadata entry, unavailable-resource acknowledgement, and delegation of discovery and export validation to the CLI.

## Impact

- **CLI:** `bin/ress` share discovery, validation, option parsing, profile generation, and porcelain/JSON consumer surfaces.
- **Panel:** `Service.qml`, `Panel.qml`, and `Model.js` state, parsing, selection, focus, and export dispatch.
- **Contracts and workflows:** `docs/contracts/loadout-profile.md`, `docs/contracts/cli-protocol.md`, `docs/workflows/share-apply.md`, `docs/panel/principles.md`, `docs/panel/status-language.md`, and `docs/panel/cli-integration.md`.
- **Architecture:** `docs/architecture/system-overview.md` for the new catalog and selection data flow while retaining CLI authority and a single authored profile repository.
- **Evidence:** focused CLI catalog/export cases, porcelain purity, model/parser tests, QML lint and cross-file checks, the full automated suite, strict OpenSpec validation, and fresh-machine panel rendering/focus verification.
- **Compatibility:** no public profile schema bump and no authored-loadout library; existing `ress share` callers and the default `~/.local/share/ress/profile` repository remain supported.
