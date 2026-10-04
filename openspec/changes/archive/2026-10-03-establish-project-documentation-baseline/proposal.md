# Proposal

## Why

ress has mature behavior, strong tests, and extensive user-facing documentation, but its intent, contracts, implementation model, and behavioral guarantees are concentrated in the README and source. Establishing a navigable documentation system and an OpenSpec baseline now will make future changes easier to reason about without allowing safety, consent, compatibility, or panel semantics to drift.

## What Changes

- Add a documentation index that declares the purpose and authority of each documentation layer.
- Add stable project vision and principles documents covering ress's purpose, audience, boundaries, trust model, and long-term direction.
- Add concise architecture, contract, panel, workflow, testing, and decision-record sections under `docs/`.
- Reorganize the existing testing guide, fresh-machine procedure, and media into the new hierarchy while updating inbound links.
- Document the CLI as the authority for machine state and the QML panel as a presentation and command-dispatch layer.
- Seed main OpenSpec capabilities, through this change's deltas, from behavior already supported by the implementation and tests.
- Add project guidance for keeping README, contracts, OpenSpec requirements, tests, and panel documentation aligned.
- Add strict OpenSpec validation to the existing verification workflow after the baseline validates cleanly.
- Preserve runtime behavior: this change documents and governs the current product rather than changing CLI, vault, loadout, or panel semantics.

## Capabilities

### New Capabilities

- `vault-capture`: Capturing selected machine-state categories into a versioned Git vault while reporting omissions and portability gaps.
- `resumable-restore`: Previewing and replaying a vault by category, resuming incomplete work, and preserving declined work for later.
- `non-destructive-defaults`: Preventing silent removal and preserving replaced files across restore and loadout operations.
- `explicit-execution-consent`: Requiring separate informed consent before building AUR packages or enabling persistent user services.
- `credential-protection`: Excluding credentials by default, scanning captured content, and supporting explicit encrypted-secret transport.
- `loadout-sharing`: Exporting and applying constrained, inspectable setup profiles without transferring dotfiles or embedded commands.
- `machine-verification`: Comparing the current machine with a vault and reporting mismatches through human and machine-readable interfaces.
- `cli-consumer-protocol`: Providing stable JSON and porcelain interfaces for automation and the panel without mixing protocol output with prose.
- `panel-integration`: Presenting backup freshness and command state while delegating machine operations and privileged restore interaction to the CLI or terminal.
- `schema-compatibility`: Versioning the vault format and retaining defined compatibility with legacy ress vault artifacts.

### Modified Capabilities

None. The project has no existing main specifications.

## Impact

- Documentation: `README.md`, the current `docs/` files and media, and new organized documentation sections.
- OpenSpec: `openspec/config.yaml`, new baseline capabilities, this bootstrap change, and validation in the repository's existing checks.
- Agent guidance: a small repository-level guidance file tying planning and implementation to the documentation authority model.
- Tests and CI: existing behavioral tests remain the evidence for the baseline; validation gains an OpenSpec structural check.
- Runtime code and public interfaces: no intended behavior change.
