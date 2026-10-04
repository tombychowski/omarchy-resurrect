# Design

## Context

See `proposal.md` for motivation. Today the README simultaneously serves as product introduction, command reference, security model, configuration guide, and architectural explanation. `docs/TESTING.md` and `docs/DEMO.md` contain strong evidence and procedures, but there is no documentation index, vision, explicit authority model, or main OpenSpec baseline. The CLI and QML panel already form two layers connected by JSON and porcelain output.

The documentation must remain proportionate to a compact Bash-and-QML project. The Endstate repositories are useful references for separating vision, contracts, workflows, UX semantics, and behavioral specs, but their duplicated contracts, incomplete indexes, stale high-level claims, and large active-change inventories are patterns to avoid.

## Goals / Non-Goals

**Goals:**

- Give contributors and agents one entry point for finding current project documentation.
- Separate durable intent, normative behavior, exact interfaces, explanatory workflows, and verification evidence.
- Document the CLI/panel boundary without creating a second source of machine-state truth.
- Seed OpenSpec from current, tested behavior and make later changes incremental.
- Preserve useful Git history and keep existing README links working after moves are updated.
- Add validation with no runtime dependency or installation impact for ress users.

**Non-Goals:**

- Redesigning CLI behavior, vault or loadout formats, consent flows, or the panel.
- Turning the documentation tree into a published documentation site.
- Duplicating the full README into topic files.
- Creating a speculative roadmap or empty operational runbooks.
- Describing every function, QML component, test helper, or implementation detail.

## Decisions

### 1. Use an explicit documentation authority model

`docs/index.md` will state the responsibility of each layer:

1. `docs/vision/vision.md` explains purpose, audience, boundaries, and direction; it is not a release claim.
2. `docs/vision/principles.md` contains durable constraints against which changes are evaluated.
3. `openspec/specs/` owns observable product behavior.
4. `docs/contracts/` owns exact external formats and consumer protocols.
5. `docs/architecture/` explains current internal structure and trust boundaries.
6. `docs/panel/` owns presentation semantics without redefining CLI state.
7. `docs/workflows/` explains supported journeys using the normative layers above.
8. `docs/testing/` describes evidence, limitations, and manual validation.
9. `README.md` remains the public landing page, installation guide, and common-use reference.

When code, tests, specs, and contracts disagree, the discrepancy is surfaced and reconciled in the same change; implementation is not silently treated as permission to weaken a stated safety guarantee.

Alternative considered: declaring either the README or code as the sole source of truth. Rejected because neither cleanly represents intent, interface stability, and observable behavior at the same time.

### 2. Keep the initial tree small and populated

The implementation will create only documents with current content:

```text
docs/
|-- index.md
|-- vision/
|   |-- vision.md
|   `-- principles.md
|-- architecture/
|   `-- system-overview.md
|-- contracts/
|   |-- vault-format.md
|   |-- loadout-profile.md
|   |-- restore-safety.md
|   `-- cli-protocol.md
|-- panel/
|   |-- principles.md
|   |-- status-language.md
|   `-- cli-integration.md
|-- workflows/
|   |-- backup-restore.md
|   |-- share-apply.md
|   `-- encrypted-secrets.md
|-- testing/
|   |-- strategy.md
|   `-- fresh-machine-validation.md
|-- decisions/
|   `-- README.md
`-- media/
```

`docs/TESTING.md` and `docs/DEMO.md` will move into `docs/testing/`. Existing documentation media will move into `docs/media/`. All repository links will be updated atomically.

Alternative considered: pre-creating roadmap, runbook, audit, and reference directories. Rejected because empty taxonomies create implied process without useful content. They can be added when a real document needs them.

### 3. Keep the vision durable and product-specific

The vision will explain the clean-install problem, the distinction between a private vault and a shareable loadout, the local-first user-ownership model, the Omarchy boundary, explicit consent, and the definition of trustworthy reconstruction. It will exclude current flag names, dependency versions, performance measurements, and implementation-specific file paths.

`principles.md` will be shorter and more normative. It will cover local ownership, least-powerful representation, explicit consent for code execution and persistence, observable truth, reversibility, honest omissions, and intentionally narrow scope.

Alternative considered: one combined vision/principles document. Separate files are chosen because vision may evolve directionally while principles are intended to constrain changes.

### 4. Treat the CLI as authority and the panel as a consumer

Panel documentation will be organized like a compact version of Endstate GUI's UX layer:

- `principles.md` defines UI guardrails.
- `status-language.md` maps CLI states to user-facing meanings.
- `cli-integration.md` defines status refresh, operation streaming, scheduling, terminal handoff, and parse-failure behavior.

These documents will not duplicate complete JSON or porcelain grammars; exact protocol definitions remain in `docs/contracts/cli-protocol.md`. The panel documents reference that contract and define only presentation responsibilities.

Alternative considered: documenting the panel entirely in the architecture overview. Rejected because presentation semantics and terminal handoff are user-facing guarantees likely to evolve independently from component structure.

### 5. Bootstrap current behavior through one reviewable change

The ten delta specs in this change describe stable behavior already supported by the code and tests. Implementation work will review each requirement against README claims, source, and tests; correct the planning artifact if evidence disagrees; and add focused tests only where the intended baseline lacks adequate evidence.

Archiving this change will merge the reviewed deltas into main specs. Subsequent work will modify those specs through ordinary OpenSpec deltas rather than directly rewriting the baseline.

Alternative considered: writing main specs directly or waiting for future changes to grow them organically. A bootstrap change is chosen because ress's safety and consent guarantees are already mature and deserve an auditable initial review.

### 6. Put workflow guidance in OpenSpec config and repository guidance

`openspec/config.yaml` will contain only planning constraints that are not useful as general documentation: pointers to the authority model, required trust-boundary analysis, documentation reconciliation, test expectations, and VM-only validation disclosure. A concise root `AGENTS.md` will tell coding agents where repository guidance lives and which checks to run.

The config will not duplicate the tech stack, command catalog, or file inventory, all of which are discoverable and more likely to become stale.

Alternative considered: placing all rules in generated agent skills. Rejected because generated skills are generic and may be refreshed independently of project policy.

### 7. Add validation to the existing verification path

Strict OpenSpec validation will be added to the existing CI workflow after the bootstrap specs validate. The implementation should use the repository's chosen pinned or reproducible OpenSpec installation mechanism and must not add a runtime dependency to the plugin.

A local pre-push framework is not part of this change. CI provides a shared gate without requiring contributors to install repository-specific hooks.

Alternative considered: adopting Endstate's Lefthook-based Level 2 gate. Rejected for now because ress already has a compact CI workflow and does not otherwise need the Node/Lefthook toolchain.

## Risks / Trade-offs

- **Documentation duplicates concepts already present in README** -> Keep README task-oriented and move only deeper rationale and exact contracts; link instead of copying long passages.
- **Baseline specs overstate what tests prove** -> Map scenarios to existing cases and label the six real-machine-only validations in testing documentation.
- **Vision and architecture become stale** -> Exclude volatile inventories and require relevant docs to be reconciled in behavior-changing proposals and tasks.
- **Ten initial capabilities feel heavy for a small project** -> Keep requirements focused on stable external behavior; do not spec internal helpers or implementation structure.
- **Moving docs and media breaks external links** -> Update every repository reference in one change and avoid unnecessary filename churn after the new canonical paths are established.
- **Contracts and OpenSpec overlap** -> Contracts own exact format detail; OpenSpec owns observable guarantees and scenarios. Cross-link rather than reproducing entire schemas.
- **OpenSpec validation adds CI setup cost** -> Pin or otherwise reproduce the CLI only in development/CI, cache when practical, and keep the ress runtime unaffected.

## Migration Plan

1. Create the new documentation directories and author the index, vision, principles, and authority model.
2. Move existing testing documents and media, then update all repository links.
3. Author architecture, contracts, panel, and workflow documents from the current implementation and tests.
4. Review each baseline delta against implementation evidence and adjust discrepancies before it becomes a main spec.
5. Add focused missing coverage only where the baseline asserts an intended automated guarantee.
6. Update OpenSpec configuration and add concise repository agent guidance.
7. Add strict OpenSpec validation to CI and run OpenSpec plus the full 21-case test suite.
8. Review the complete documentation index for orphaned current documents and broken links.
9. Archive the change after implementation and review so the deltas become the main behavioral baseline.

Rollback consists of reverting the documentation moves, guidance, CI validation, and unarchived change together. No vault or user-state migration is involved.
