# Design

## Context

`ress share` currently has one discovery-and-render path: it reads explicit packages, qualifying plugins, representable user web apps, and the active theme, then writes schema-version-1 `profile.json` and `README.md` into one Git repository. `Service.qml` invokes that command without arguments, while `Panel.qml` provides no inventory or metadata editor.

The applied-loadout registry already stores validated normalized profile snapshots and live resource health is available through CLI adapters. Those facts can seed selections, but the registry is machine-local deletion-authority state and must not be exported or interpreted directly by QML. The public profile remains a constrained package/integration description with one theme object; the composer cannot broaden it into files, commands, secrets, or multiple themes without a schema change.

See `proposal.md` for motivation and the delta specs for observable behavior.

## Goals / Non-Goals

**Goals:**

- Give both CLI and panel users one authoritative catalog of current share candidates and truthful refusal reasons.
- Preserve a one-step path to select all shareable resources while allowing precise subset composition.
- Reuse the current export and applied loadouts as selection seeds without copying stale definitions or machine-specific ownership.
- Make a selective export fail closed if selected resources or withdrawal acknowledgements are stale.
- Keep the panel responsive, compact, and fully keyboard operable with large package inventories.

**Non-Goals:**

- Managing a library of authored loadouts, multiple profile repositories, remotes, or publication destinations.
- Changing schema version 1, exporting several themes in one profile, or changing apply behavior.
- Editing an applied loadout, transferring registry provenance, or treating applied-loadout membership as proof of current machine state.
- Publishing or pushing the generated repository, adding a hosted service, or performing network discovery during catalog generation.
- Making unpinned, local-only, unsupported, or credential-bearing resources shareable.

## Decisions

### 1. Add one CLI share catalog backed by the export collectors

`ress share catalog --json` will be the panel's discovery boundary. It will return a versioned object with:

- `resources`: current package, plugin, web-app, and theme candidates;
- `currentExport`: `valid`, `absent`, or `unavailable` state, metadata, available membership, and unavailable prior entries;
- `presets`: applied-loadout availability and per-loadout eligible membership plus warnings; and
- category counts and capability limits needed for presentation, including the one-theme maximum.

Each candidate will carry a stable logical id, kind, display name, category-specific non-executable metadata, `shareable`, and a bounded reason code plus display-safe explanation when unavailable. The JSON will not contain home-file content, commands, secrets, URL credentials, registry cleanup policy, or ownership evidence.

Discovery and full export will use the same collector functions. This prevents the panel from offering an item that the ordinary exporter defines differently. Packages remain explicitly installed native or foreign packages; plugins require a valid id, safe credential-free HTTPS remote, and exact commit; web apps must reduce to the supported name/HTTPS URL/icon form; custom Git themes require a safe remote and exact commit, while known bundled themes may travel by name. Package-owned launchers are not user share candidates. Theme candidates use `theme-install:<name>` as the selection identity; selecting one continues to produce the profile's coupled install-and-activate theme object.

Alternatives considered:

- **Read package, plugin, launcher, profile, and registry files from QML:** rejected because it creates a second machine-state and validation implementation.
- **Build the catalog from the vault:** rejected because share currently reflects the live machine, vault state may be stale, and vault payloads have a wider confidentiality boundary.
- **Return only shareable resources:** rejected because it would hide omissions the user may need to fix or acknowledge.

### 2. Keep optional catalog sources independently available

Machine candidate discovery, current-profile parsing, and applied-loadout preset discovery have separate availability states. A malformed registry disables applied-loadout presets but does not erase an independently valid machine catalog or current export. A missing profile reports `absent`; a malformed profile reports `unavailable`, never a valid empty export. The panel strictly validates the complete catalog envelope and each record before publishing it.

This is a display/read boundary only. Registry validation remains unchanged and no catalog result can authorize resource removal or other machine mutation.

Alternative considered: fail the entire catalog when any optional source is invalid. That is simpler but prevents safe manual composition for an unrelated malformed preset source and conflates unavailable state with machine discovery failure.

### 3. Use explicit selection mode with logical ids and bound acknowledgements

The existing invocation remains unchanged:

```text
ress share [--name NAME] [--description TEXT] [--out DIR]
```

Selective callers use an explicit marker and repeated argument-array values:

```text
ress share --custom \
  --select package:ripgrep \
  --select plugin:example.widget \
  --acknowledge-unavailable RESOURCE_ID FINGERPRINT \
  --name NAME --description TEXT
```

`--custom` distinguishes an intentionally empty selection from the legacy no-filter invocation. The CLI rejects custom mode with zero selections, duplicate or unknown ids, or more than one theme. Repeated options avoid delimiter parsing, and QML sends them as process arguments rather than a shell command. Expected Omarchy inventories remain comfortably below normal argument-vector limits; the implementation will cover a representative large inventory and can add stdin input later without changing the catalog or profile contracts.

The panel sends only ids and acknowledgement fingerprints. The CLI reconstructs every definition from a fresh machine scan, compares it with the catalog-valid rules, validates metadata, and renders the profile. It never trusts URLs, commits, launcher definitions, channels, or theme data supplied by QML.

Unavailable entries from the valid current profile carry an acknowledgement fingerprint over their canonical profile definition. The CLI rereads the current profile at export and accepts acknowledgement only when both id and fingerprint still match. This is a concurrency/staleness token, not an authorization secret. A newly unavailable or changed prior entry therefore requires a new catalog and acknowledgement.

Alternative considered: accept a complete profile or resource definitions from the panel. That would duplicate validation and let a stale or malformed UI payload choose executable or network-relevant definitions.

### 4. Reinspection precedes any profile mutation

Selective export will acquire a profile-output lock, then:

1. load and validate the current profile when present;
2. rediscover all selected resources;
3. validate selection cardinality, definitions, metadata, and exact withdrawal acknowledgements;
4. render `profile.json` and `README.md` into temporary files;
5. replace the generated files only after the complete plan is valid; and
6. stage and commit through the existing repository behavior, retaining its remote and configured share-link handling.

Any validation refusal occurs before generated files change. The profile lock serializes panel and direct-CLI exports to the same output repository without claiming the broader machine-mutation lock. A custom `--out` directory receives the same protection scoped to that output.

The name must be non-empty display-safe text and the description display-safe bounded text. The exact limits and refusal reason codes belong in the loadout-profile and CLI-protocol contracts. Author and Omarchy version continue to come from the CLI's existing local sources.

Alternative considered: write the selection into persistent draft state before export. This adds recovery and migration obligations to a low-risk local composition flow and complicates a later authored-loadout library, so drafts remain panel-session state.

### 5. Current export and applied loadouts seed identities, not definitions

A valid current profile is normalized through the existing profile rules and mapped to catalog identities. An entry is selected automatically only when its current machine definition still matches. A missing, unshareable, or definition-mismatched entry appears as an unavailable placeholder with its acknowledgement fingerprint. The user may select an independently shareable current definition manually, but that is visibly a replacement rather than silent preservation of the old pin or launcher definition.

Applied presets are derived by the CLI from normalized stored snapshots plus current inspection:

- present or protected, definition-compatible resources are eligible;
- missing, pending, modified, conflicting, failed, uncertain, or unverifiable resources are warnings and are not auto-selected; and
- resource membership is mapped to catalog identities without exporting cleanup policy, claim outcomes, or loadout-local active-theme ids.

Starting from a preset selects its eligible identities. Adding another preset unions non-theme identities without duplicates. Its theme is selected only when no theme is currently selected; a different existing theme is retained and the conflict is shown for explicit resolution. Metadata fields use the valid current export's name and description when available, otherwise the existing CLI defaults; applied presets never copy another author's metadata automatically.

Alternative considered: copy stored applied profiles verbatim. That can export missing resources or stale plugin commits and contradicts the established live-machine meaning of `ress share`.

### 6. The Share tab becomes a small state machine

The panel keeps its three top-level tabs. The Share tab has these in-memory states:

```text
loading --> choose-start --> compose --> exporting
    |            |             |            |
    +--> unavailable <---------+<-- refusal-+
```

The start screen presents four explicit choices: all shareable resources, current export, empty selection, or an applied loadout. The all-resources choice is visually primary so the simple path remains short. Unavailable choices stay visible with an explanation.

Composition shows editable name and description, category summary rows, selected counts, and an export summary. Entering a category reveals a search field and a virtualized or otherwise bounded list of resource toggles; it does not render every package in the top-level panel. Unavailable items and preset warnings remain inspectable. Themes use radio semantics. Current-export unavailable entries expose acknowledgement controls tied to their fingerprints.

`Model.js` validates catalog shapes and owns pure selection helpers. `Service.qml` owns asynchronous catalog collection and CLI dispatch. `Panel.qml` owns only ephemeral form and selection state. Export success refreshes the catalog and current-export seed; a stale refusal preserves the user's form where safe, refreshes authoritative state, and requires review rather than claiming success.

All state transitions, metadata fields, search, toggles, acknowledgement controls, and back navigation join the existing keyboard cursor model. Real rendering and focus behavior remain a fresh-machine verification boundary even after model, lint, and cross-file tests pass.

### 7. Profile schema and publication behavior do not migrate

The output remains schema version 1 with one `theme` object and the same default `~/.local/share/ress/profile` Git repository. No authored-profile registry is introduced. Existing remotes, Git history, `PROFILE_URL`, copy-share-command behavior, and `--out` remain intact. The catalog is a local read interface and does not push, fetch, resolve a short link, or contact a hosted service.

This leaves a clean future path for an authored-loadout library: it can select multiple output directories through the existing `--out` boundary without changing resource selection or the public loadout schema.

## Risks / Trade-offs

- **[Catalog and export collectors diverge]** -> Implement one canonical resource-record collector and filter/render from it; test catalog-to-profile round trips for every kind.
- **[Large package inventories make the panel dense or slow]** -> Fetch only while the Share tab is used, group by category, search within a bounded detail view, avoid top-level delegates for every item, and test a representative large catalog.
- **[A resource changes between catalog and export]** -> Reinspect under the profile lock and refuse before replacing generated files; refresh the catalog after refusal.
- **[An unavailable current resource is silently withdrawn]** -> Bind acknowledgement to id plus canonical-definition fingerprint and compare against the freshly validated current profile.
- **[Applied preset state is malformed]** -> Mark presets unavailable independently; never infer membership from registry files in QML.
- **[Argument-vector size becomes a practical limit]** -> Measure a high but realistic package selection; add a documented stdin transport later if needed without changing resource identities or export semantics.
- **[Metadata damages terminal or generated Markdown presentation]** -> Apply bounded control-character validation and render metadata as data; cover terminal, JSON, README, and Git-message cases.
- **[Profile file replacement succeeds but Git commit fails]** -> Report a qualified outcome and leave inspectable generated files rather than claiming publication success; preserve the existing repository for manual recovery.
- **[Custom local themes appear portable]** -> Mark themes without a bundled identity or safe pinned remote unavailable and explain why.
- **[The richer Share tab becomes a dashboard]** -> Keep explicit start choices and category summaries at the top level; disclose long lists and refusal detail only when requested.

## Migration Plan

1. Add catalog collection and selective CLI parsing behind additive command forms while retaining the existing unfiltered share path.
2. Add protocol parsing and model tests before switching the panel Share tab to the composer.
3. Enable the composer against the same single default profile repository; no data migration or profile rewrite occurs until the user exports.
4. Update contracts, workflow, architecture, panel language, and verification guidance with the implemented command and reason-code shapes.
5. Rollback consists of restoring the prior CLI and panel. Profiles remain schema version 1 and readable; the additive catalog command and custom flags simply become unavailable, while existing repositories and remotes remain intact.
