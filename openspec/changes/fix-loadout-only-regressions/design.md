# Design

## Context

See proposal.md for the audited defects. The branch has uncommitted removal work; corrections must remain attributable without staging or changing project history. Existing panel composition requirements remain authoritative.

## Goals / Non-Goals

Strengthen existing boundaries with no new dependency or generic adapter framework. Keep CLI state authoritative and preserve approved removal scope. No new panel authoring mode, format conversion, or automatic ownership repair is included.

## Decisions

- Share a destination-path validator in repository transactions. Validate existing ancestors as nonsymlink directories and the canonical intended path before publication and recovery; import also checks source/library ancestor overlap before preview and again under lock. This prevents callers from bypassing containment without recreating the port framework.
- Retain the established schema-1 journal `backup` field (temporary prior publication content, not the removed product). Accept the branch's interim `original` representation with the same strict path rules so both existing states are recoverable. Reject mixed/unknown keys. Keeping stable persisted syntax avoids unnecessary version churn.
- Capture package inventory exit status before using any output. A failed snapshot is cached as unavailable for the command; resource inspection returns unverifiable and existing conflict handling prevents mutation/new ownership. Refresh observations after effects as already required. No partial inventory is treated as authoritative.
- Collect check JSON and finalize the view on process completion, accepting only documented exits 0/1 with valid output. Test actual Service handler code and actual CLI payloads. Restore field focus and preset union in presentation/Model while CLI continues to define eligibility.
- Guard unchanged-content provenance updates with dry-run. Advisory changed-content evidence remains allowed and is disclosed in preview wording. Migration remains locked and atomic; normal output producers expose the command-local migration result, with no stray JSON stdout.
- Separate file/directory doctor checks and remove unused unit fixture state. Reconcile exact contracts, panel workflow, spec wording, and evidence limits.

## Risks / Trade-offs

- Cooperative locks do not stop an unrelated process racing directory replacement; revalidate paths at the mutation boundary and refuse known symlinks. Do not claim protection against arbitrary concurrent hostile filesystem writes.
- Inventory failure may block package workflows that previously appeared successful; this is required preservation behavior, not a new bypass option.
- UI tests execute handlers and protocol adapters without claiming rendered focus/layout evidence. Disposable Omarchy validation remains necessary for real keyboard and package effects.

## Migration Plan

No authoritative registry schema change. Both established and interim journal representations remain readable; new writes use the established representation. Existing incorrectly acquired package authority is not silently rewritten: users must review such historical records. Keep inherited package and dry-run fixes identifiable in the final review.
