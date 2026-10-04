# Tasks

## 1. Reconcile the behavioral baseline

- [x] 1.1 Build a traceability matrix for the ten proposed capabilities, mapping every requirement and scenario to its current implementation and supporting test or documented manual verification. Verify that each scenario has a concrete evidence reference or an explicit fresh-machine/manual-only classification.
- [x] 1.2 Reconcile any discrepancies found in the traceability matrix by correcting the delta specs to describe current behavior rather than intended future behavior. Verify the result with `openspec validate establish-project-documentation-baseline --type change --strict`.
- [x] 1.3 Add or refine focused automated tests only where an existing behavioral guarantee is intended to be testable but lacks evidence; otherwise record why the guarantee requires manual or VM validation. Run every affected test case and record the result in the traceability matrix.

## 2. Establish the documentation foundation

- [x] 2.1 Create `docs/index.md` as the documentation entry point, including the authority hierarchy, audience-oriented navigation, and links to every maintained document. Verify that every document under `docs/` is reachable from the index or from a directly linked section index.
- [x] 2.2 Create `docs/vision/vision.md` describing the project purpose, target user outcome, boundaries, and long-term direction without presenting planned work as shipped behavior. Verify its claims against the README and the reconciled capability baseline.
- [x] 2.3 Create `docs/vision/principles.md` with durable product and engineering principles, including non-destructive defaults, explicit consent, resumability, secret protection, CLI authority, and honest status reporting. Verify that each normative principle is reflected in at least one capability spec or clearly identified as design guidance.
- [x] 2.4 Create `docs/architecture/system-overview.md` covering the CLI, panel, persistent state, external tools, and trust boundaries. Verify component names and data flows against the manifest, entry points, service/model code, and current command implementation.
- [x] 2.5 Update the root README to remain the concise public landing page while linking prominently to the documentation index for deeper material. Verify all README links and quick-start commands still resolve.

## 3. Document durable contracts

- [x] 3.1 Create `docs/contracts/vault-format.md` documenting vault layout, metadata, payload ownership, schema-version handling, legacy compatibility, and secret-bearing paths. Verify the contract against the vault code and the vault/schema compatibility tests.
- [x] 3.2 Create `docs/contracts/loadout-profile.md` documenting profile format, export/import semantics, portability boundaries, and validation behavior. Verify examples and guarantees against the loadout implementation and sharing tests.
- [x] 3.3 Create `docs/contracts/restore-safety.md` documenting preview, explicit execution consent, checkpointing, resume behavior, non-destructive defaults, and failure handling. Verify each guarantee against the restore implementation and its focused safety/resume tests.
- [x] 3.4 Create `docs/contracts/cli-protocol.md` documenting stable machine-consumable output, progress and terminal states, exit behavior, and compatibility expectations for consumers. Verify the protocol against current CLI output paths plus CLI-consumer and panel integration tests.

## 4. Document the panel as a CLI consumer

- [x] 4.1 Create `docs/panel/principles.md` describing the panel's scope, compact presentation model, progressive disclosure, and refusal to invent state. Verify the guidance against the current panel layout and model/service responsibilities.
- [x] 4.2 Create `docs/panel/status-language.md` defining user-facing wording for idle, previewing, running, partial, complete, failed, and resumable states. Verify that every current terminal and in-progress state has one unambiguous presentation.
- [x] 4.3 Create `docs/panel/cli-integration.md` describing how the panel invokes the CLI, consumes protocol output, handles errors, and preserves CLI authority. Verify the documented flow against the panel service/model implementation and relevant integration tests.

## 5. Add workflows and migrate existing documentation

- [x] 5.1 Create `docs/workflows/backup-restore.md`, `docs/workflows/share-apply.md`, and `docs/workflows/encrypted-secrets.md` as task-oriented guides that link to the governing contracts rather than duplicating them. Verify every command and option against CLI help and the corresponding automated tests.
- [x] 5.2 Move the existing testing guide to `docs/testing/strategy.md` and the demo/fresh-machine material to `docs/testing/fresh-machine-validation.md`, preserving still-valid guidance and distinguishing automated coverage from VM/manual evidence. Verify that the documented test counts and claims match a current test run.
- [x] 5.3 Move documentation media into `docs/media/` and update every reference to the new locations. Verify with a repository-wide search that no links retain the old media paths and that each referenced asset exists.
- [x] 5.4 Create `docs/decisions/README.md` defining when an architectural decision record is warranted and the minimum decision-record structure, without creating speculative ADRs. Verify that the documentation index links to this guidance.

## 6. Add OpenSpec governance and continuous validation

- [x] 6.1 Update `openspec/config.yaml` with only project-specific planning constraints that are not already discoverable from the repository, including the documentation authority model and the rule that current-behavior claims require evidence. Verify the file remains valid for the installed OpenSpec CLI.
- [x] 6.2 Add a concise root `AGENTS.md` that directs contributors and agents to the documentation index, vision/principles, OpenSpec workflow, test entry point, and CLI-as-authority rule. Verify that its instructions do not conflict with repository scripts or the OpenSpec configuration.
- [x] 6.3 Add reproducible OpenSpec CLI setup and strict validation to the existing CI workflow without adding an application runtime dependency. Verify workflow syntax and run the exact strict-validation command locally.

## 7. Complete integration verification

- [x] 7.1 Run `openspec validate establish-project-documentation-baseline --type change --strict` after all artifact adjustments and resolve every reported issue.
- [x] 7.2 Run the full repository test suite with `./tests/run.sh` and reconcile the testing documentation with the observed case and assertion totals.
- [x] 7.3 Audit documentation navigation and relative links from the README and `docs/index.md`, confirm that no maintained document or media asset is orphaned, and correct all broken references.
- [x] 7.4 Review the final diff to confirm that the change only establishes documentation, tests needed to substantiate existing guarantees, OpenSpec guidance, and CI validation, with no unintended runtime behavior changes.
