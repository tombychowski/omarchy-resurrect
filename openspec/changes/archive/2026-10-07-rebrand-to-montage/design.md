# Design

## Context

See [proposal.md](proposal.md) for motivation. The current plugin has one `ress` shell entrypoint, sourced modules under `lib/ress/`, Ress-specific XDG state, a root-profile sharing repository, and a Git-backed vault whose current controls and panel surfaces assume one live Ress product identity. The CLI is authoritative for inspection, validation, machine mutation, durable state, and consumer output; QML consumes those results.

This change crosses plugin installation, command resolution, persistence, Git synchronization, untrusted repository input, compatibility conversion, and panel trust boundaries. Montage and Ress must remain installable side by side, while only explicit conversion may cross between them. Existing safety, consent, preservation, credential, provenance, and cleanup rules remain constraints rather than migration trade-offs.

## Goals / Non-Goals

**Goals:**

- Establish one internally consistent Montage implementation with a short, collision-resistant public command and independent plugin, IPC, and XDG identities.
- Give the CLI a reusable repository layer that owns identity, validation, locking, atomic writes, Git commits, history selection, and safe synchronization for loadout and vault repositories.
- Keep constrained loadout leaves portable while allowing Montage-owned repository metadata and future repository capabilities to evolve independently.
- Make Ress compatibility a small, testable conversion boundary whose source and destination can be audited separately.
- Preserve a rollback path in which a user can remove Montage and continue using an untouched Ress installation and its artifacts.

**Non-Goals:**

- Providing `ress` or `montage` command aliases, reading Ress runtime state during ordinary operation, or maintaining a shared-live-directory mode.
- Following future Ress formats automatically or promising behavioral parity with future Ress releases.
- Turning loadouts into arbitrary configuration bundles or executable automation.
- Synchronizing secrets, GitHub credentials, applied-loadout ownership, locks, restore checkpoints, or other operational state.
- Building a general Git conflict resolver or using forced history updates as normal synchronization behavior.
- Introducing a Montage-specific portable leaf schema before its additional semantics are known.

## Decisions

### 1. Rename the implementation completely and keep compatibility code at the edge

The executable becomes `bin/mntg`, sourced production modules move to `lib/montage/`, and active internal names, QML identifiers, tests, paths, messages, generated native documentation, and package metadata use Montage. The plugin id and IPC namespace become `tombychowski.montage`. No Montage-owned `bin/ress`, `ress` symlink, or `montage` executable is shipped.

The only active Ress-named production area is the bounded `lib/montage/port/adapters/ress_v1/` adapter; Ress fixtures and historically accurate archived evidence may also retain their names. Format-neutral lifecycle and safety code stays under `lib/montage/port/` without Ress vocabulary. This makes accidental dependency on legacy behavior visible in review.

`mntg` was selected over `montagectl` because it is materially shorter, and over `montage` because stock Omarchy may already provide ImageMagick's command with that name. `mntg link` creates `~/.local/bin/mntg` only when the path is absent or already an owned link to the active installation. An unrelated file or link is a hard error.

Alternative considered: retain a `ress` compatibility wrapper. Rejected because it would create command ownership ambiguity when both products are installed and would broaden the legacy surface Montage must maintain.

### 2. Isolate all live state with XDG roots and a Montage repository registry

Configuration lives below `${XDG_CONFIG_HOME:-~/.config}/montage`, operational state and locks below `${XDG_STATE_HOME:-~/.local/state}/montage`, and Montage-managed data and default repositories below `${XDG_DATA_HOME:-~/.local/share}/montage`. Configuration records named repository entries containing a validated local path, repository type, expected stable repository identity, and optional credential-free remote metadata.

Repository paths may point elsewhere on the local filesystem, but a configured Ress artifact path can only be used as an explicit import source. Before each mutation, the CLI resolves the configured path, validates containment and repository identity, and takes the applicable Montage lock. The panel updates this registry only through serialized CLI configuration commands.

Alternative considered: let Montage point directly at Ress vault and profile directories. Rejected because two programs could interpret, migrate, lock, commit, or clean the same files differently and because that approach would make Montage's schema roadmap subordinate to Ress.

### 3. Use `montage.json` as a repository envelope, not a replacement for every leaf

Every native repository has a root `montage.json` with a plain integer schema version, repository kind (`loadouts` or `vault`), stable repository identity, and kind-specific non-secret metadata. Exact fields, bounds, and canonical JSON forms belong in the repository contracts.

The envelope answers which product owns the container, what type of repository it is, and which validators apply. It does not duplicate item content, store credentials, or grant cleanup authority. This is why `montage.json` is valuable even though `profile.json` remains unchanged: it versions the collection without branding or prematurely forking the portable leaf.

Alternative considered: rename every `profile.json` to `montage.json` and change the leaf kind to `montage-loadout`. Rejected because the existing schema-version-1 `omarchy-loadout` format already expresses the intentionally constrained portable unit and is not Ress-branded. A new leaf kind will be introduced only with new semantics and an explicit conversion story.

### 4. Model a loadout repository as a collection of stable identities

A loadout repository stores items at `loadouts/<stable-id>/profile.json`. The bounded path id is immutable; name, description, profile digest, and content may change. The repository envelope is not an editable index whose membership can drift from the directory tree. The CLI enumerates contained directories, validates each profile, and reports invalid entries without merging identities.

Writes use a repository lock, a same-filesystem staging directory, full profile and containment validation, atomic replacement of the selected item, and then one Git commit when content changes. A failed validation leaves the selected item, other items, and repository history unchanged.

For external application, the canonical shape is `mntg apply <repository-source> --loadout <stable-id>`. For configured local repositories, commands pass a repository selector plus the stable loadout id. A source containing one loadout may be selected interactively, but scripts and generated instructions include the selector explicitly. Applied-loadout state stores the sanitized source, repository id, loadout id, resolved commit, profile digest, and validated snapshot.

Alternative considered: one Git repository per loadout. Rejected because it makes local catalog management and shared synchronization unnecessarily fragmented. Alternative considered: use a mutable display name as identity. Rejected because rename would break links, applied-state reconciliation, and withdrawal acknowledgements.

### 5. Use linear Git commits as immutable vault backup identities

A vault repository represents one machine lineage. Its checked-out current tree contains `montage.json`, `backup.json`, and the captured payload. After capture, credential screening, and full validation succeed, the CLI atomically publishes the staged tree and creates one content-changing commit. The commit id is the backup identity; unchanged captures report the existing commit rather than manufacturing history.

History queries use Git object reads or an isolated temporary worktree and never change the user's checkout. A candidate commit is restorable only after the envelope, backup manifest, payload boundaries, and contained controls all validate at that exact commit. Restore preview, confirmation, and progress persist the repository identity plus resolved commit rather than a mutable branch or label.

Human labels use validated Montage-managed Git refs that resolve to one commit. A confirmed retention operation may rewrite local reachability after preview. Because normal sync never force-pushes, a local history rewrite that conflicts with an already published remote is reported as divergence; the user must retain the remote history, choose a new private remote, or perform explicitly external repository administration. Montage does not disguise destructive remote rewriting as retention.

Alternative considered: duplicate every backup into a timestamp directory. Rejected because it needlessly duplicates Git's snapshot model and increases both storage and schema complexity. Alternative considered: silently restore `HEAD`. Rejected because mutable refs cannot safely bind preview or resume state.

### 6. Keep Git synchronization conservative and credential-independent

Repository sync is CLI-owned and uses the user's existing Git transport, SSH agent, or credential helper. Montage stores and displays only canonical credential-free remotes. It does not store tokens or private keys.

Sync first fetches and classifies the relationship: equal, local fast-forward ahead, remote fast-forward ahead, or divergent. It may push or fast-forward only when the result preserves both known histories without rewriting. Divergence produces a preview and decision-required result; initial scope does not auto-merge repository content. Push rejection, authentication failure, and partial ref results remain explicit failures.

Loadout repositories may be public or private. Vault repositories are documented as private personal backup storage. If GitHub visibility is safely available through an existing authenticated tool or API, a known-public vault remote requires a warning and confirmation; inability to determine visibility is reported rather than treated as proof of privacy.

Alternative considered: embed GitHub API tokens and implement hosting-specific synchronization. Rejected because ordinary Git is sufficient for the data path and token custody would add a new secret boundary. Alternative considered: force-push after local changes. Rejected because it can destroy backups or another machine's work.

### 7. Use a format-neutral port lifecycle with bounded adapters

The shared port layer owns adapter selection, source/destination separation, absent-or-empty destination validation, isolated Git revision materialization, versioned report projection, exact loss acceptance, dry-run behavior, confirmation, native item selection, native repository locking and setup, staging, validation sequencing, Git commits, and atomic publication. Its report envelope is `kind: "montage-port-report"`; `format` identifies the selected adapter contract such as `ress-v1`. Dispatch uses an explicit allowlist rather than constructing function names from user input.

Each adapter owns only its descriptor and capabilities, foreign filenames, schemas, version boundary, artifact detection, semantic inspection facts, loss and decision discovery, translation callbacks, and validation of staged foreign output. Adapters return facts through a generic port context and never perform confirmation, Git history traversal, native repository creation or selection, locking, staging, commits, publication, or consumer output. An adapter must use the shared lifecycle and cannot weaken credential, containment, consent, private-key, cleanup-authority, or publication guarantees. Adding a future format therefore requires a new adapter, fixtures, conformance cases, and format-specific documentation rather than copying the dispatcher and safety implementation.

Historical materialization is one envelope-neutral Git-object reader shared by native repository history and foreign adapters. It validates bounded paths and object modes, reconstructs only contained blobs and links in a private temporary tree, and leaves format validation to the caller. Native readers layer `montage.json` validation on that tree; port adapters layer their own foreign validation on the same safe primitive. Archive extraction is not a second historical-read implementation.

Because Bash has no interface type, one compact shared dispatcher maps a
literal `(format, callback)` pair to a hard-coded adapter function. User input
is never evaluated as a function name, and adding a callback does not require a
new pass-through wrapper. Adapter selection initializes immutable descriptor
facts such as canonical format id and target version; operation callbacks
populate only the context fields that vary for an inspected artifact or
decision. The engine operates on one format-neutral `PORT_ADAPTER_*` context,
so adapters do not mirror those facts in a second format-prefixed runtime
context.

Mutation labels, report refusal/output, dry-run completion, and native
publication sequencing are properties of the shared operation rather than
adapter callbacks. Common command arguments are parsed once by the shared
command layer; adapters parse only genuinely format-specific decisions. Small
helpers may consolidate repeated result and staging paths, but preview-time and
post-confirmation validation remain separate because a source or destination
can change while the user is deciding.

The Ress v1 adapter accepts only the Ress schema and artifact names documented at the compatibility baseline. It parses JSON and bounded data as data; it never sources artifact content or adopts Ress configuration, locks, remotes, registry records, credentials, private keys, restore checkpoints, or cleanup ownership.

The flow is inspect, plan, stage, translate, validate, report, confirm, and atomically publish to a new or explicitly empty destination. Default Ress import converts the selected current snapshot or loadout into fresh Montage history with no remote. Optional history import materializes each supported source commit in isolation, translates it in chronological order, and creates new Montage commits; original hashes are not claimed to survive. Any unsupported revision stops publication unless the user explicitly chooses a reported compatible subset.

Export materializes one selected Montage backup or loadout into a separate disposable Ress v1 directory. It never changes the native repository. Representational loss requires itemized opt-in, while loss of safety, consent, credential, containment, or cleanup semantics is not waivable. Encrypted ciphertext may be copied when the target format can represent it, but identity configuration and private keys are never ported.

Ress and Montage plugin entries remain distinct. The adapter reports self-plugin entries and requires an explicit include, omit, or supported mapping decision; it never silently substitutes one plugin for the other.

Alternative considered: keep every lifecycle, reporting, and safety concern in one format-named file. Rejected because a future adapter would either duplicate high-risk policy or depend on Ress-named implementation details. Alternative considered: implement broad bidirectional live compatibility in native readers. Rejected because it would spread legacy conditions through backup, restore, sharing, registry, and panel code and give future Ress changes leverage over Montage's design.

### 8. Keep all repository and migration interpretation in the CLI

Repository discovery, envelope and leaf validation, Git status and history, synchronization classification, backup selection, port planning, and final mutation live in CLI modules. Human output, versioned JSON query results, and porcelain operation records are projections of the same validated model.

The panel stores only transient UI selection. It requests repository lists, loadout items, backup commits, synchronization previews, port previews, and share catalogs from `mntg`. It does not read `.git`, `montage.json`, `backup.json`, `profile.json`, or Ress artifacts directly. Machine-changing, destructive, privileged, divergent-sync, and port-publication flows open an interactive terminal.

Alternative considered: use QML JavaScript to scan repositories for responsiveness. Rejected because it would create a second security and compatibility implementation and could disagree with terminal operations.

### 9. Preserve repository input as hostile until exact-snapshot validation completes

Native clones, local repositories, Git history, and Ress sources are untrusted. Control paths must be contained regular non-symlink files. Directory copies and replay never follow links outside the selected tree. Stable ids and refs are validated before path or command construction. Historical reads use Git object APIs or isolated temporary worktrees rather than checking out over a configured repository.

All external command arguments use arrays or otherwise avoid shell evaluation. Temporary material is created with restrictive permissions and removed on success or preserved with a reported path only when that is necessary for recovery. Publication uses same-filesystem atomic renames where possible and an explicit recoverable journal where multiple state files must change together.

Alternative considered: trust locally configured repositories. Rejected because they may have been cloned, synchronized, edited, or replaced since configuration.

### 10. Treat this as a new product release, not an in-place Ress upgrade

The marketplace entry, repository metadata, install examples, release artifacts, screenshots, site content, and support language present Montage independently. Historical changelogs and archived OpenSpec changes remain unchanged; current docs and main specs become Montage-native. Compatibility contracts identify Ress only where the port boundary requires it.

There is no automatic migration at plugin startup. Users install Montage, initialize native repositories, preview explicit Ress imports if desired, verify results, and then decide independently whether to keep or remove Ress. This sequencing is central to coexistence and rollback.

Alternative considered: reuse the published `resurrect` marketplace identity and silently migrate on update. Rejected because it would replace another product's installation and make rollback or side-by-side verification unsafe.

## Risks / Trade-offs

- **[Breaking command and path rename]** Existing scripts and keybindings will not find `ress`. → Publish a command/path migration table, update all generated examples, provide actionable “command not found” guidance in release notes, and intentionally avoid an ambiguous compatibility alias.
- **[Large rename obscures behavioral changes]** Mechanical movement can hide repository or safety regressions. → Stage implementation by layer, keep focused commits where practical, add path-leak checks, and require behavior-focused tests in addition to search-based rename checks.
- **[Portable v1 leaves constrain future Montage features]** Repository features may eventually outgrow `omarchy-loadout`. → Keep Montage metadata in the envelope and introduce a new leaf kind only through a separately specified versioned change.
- **[Git divergence requires user action]** Conservative sync will sometimes stop instead of completing automatically. → Return exact ahead/behind/divergence evidence, preserve both histories, and open an interactive resolution path without force.
- **[Vault retention and published linear history conflict]** Removing local historical reachability can make the branch diverge from an existing remote. → Preview exact commits, require confirmation, never force-push, and document new-remote or external-admin choices.
- **[History conversion is expensive and partial]** Old Ress commits may use inconsistent or unsupported artifacts. → Default to current snapshot, isolate and validate every requested revision, publish nothing on failure, and allow only explicit compatible-subset selection.
- **[Two installed panels could confuse users]** Ress and Montage may expose similar actions. → Use distinct plugin ids, IPC targets, panel branding, commands, paths, and documentation; never auto-disable or remove Ress.
- **[Vault remotes expose sensitive metadata]** Even encrypted secret payloads and package/config inventories are personal data. → Default guidance to private repositories, sanitize remotes, warn on known-public GitHub visibility, and never sync credentials or keys.
- **[Stale repository paths can target the wrong data]** A path can be replaced after configuration. → Store the expected repository id and revalidate the resolved path and envelope under lock before every mutation.

## Migration Plan

1. Add repository, envelope, identity, containment, Git-classification, and atomic-publication primitives behind tests while the existing CLI remains the test oracle.
2. Rename the executable, modules, plugin/QML/IPC identity, XDG roots, runtime messages, harness entrypoints, and active fixtures to Montage in one breaking implementation phase. Add the guarded `mntg` link flow and checks that no active Montage path writes Ress state.
3. Introduce Montage loadout and vault repository contracts and commands. Migrate native backup, restore, share, apply, registry, status, verify, and consumer-protocol paths to exact repository and commit identities.
4. Implement conservative sync and history isolation, then add the Ress v1 adapter and its frozen fixtures. Keep import/export unavailable until preview, loss, containment, atomicity, and source-preservation evidence passes.
5. Update panel surfaces to consume the finalized CLI JSON contracts. Route consent-bearing operations through an interactive terminal and verify keyboard-only workflows.
6. Reconcile main specs, contracts, architecture, workflows, panel language, testing guidance, README, site/media, marketplace metadata, and release documentation. Preserve archived changes and historical changelogs.
7. Validate focused automated cases throughout, then run the full suite and strict OpenSpec validation. Record real-machine and clean-Omarchy evidence for plugin coexistence, rendering, link collision, install/update/remove independence, GitHub authentication and visibility, sync divergence, and restore from historical commits.
8. Release Montage as a separate marketplace plugin. Migration guidance has users install it beside Ress, initialize native repositories, preview and confirm selected imports, verify backups/loadouts, and only then remove Ress if desired.

Rollback does not mutate Ress: disable or remove `tombychowski.montage`, remove only the owned `mntg` link if requested, and continue using the untouched Ress plugin and artifacts. Montage repositories remain ordinary user-owned Git repositories. A rollback of Montage itself must not run an older binary against a newer unsupported envelope; users retain the repository and install a compatible Montage version or restore a repository copy rather than downgrading schemas in place.
