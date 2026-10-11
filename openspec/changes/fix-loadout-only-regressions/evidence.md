# Corrective review and evidence

Date: 2026-10-10. Branch: `feature/remove-backup-restore`; base HEAD:
`9a86febbf18c7a1bcb22d02f8995db3d4beeb954`. Implementation and evidence are
uncommitted. The archived Loadout-only removal remains approved.

## Finding disposition

| Audited finding | Correction | Focused evidence |
|---|---|---|
| P1 Ress destination escape | Central canonical/ancestor validation; source/library overlap refusal; locked revalidation | `50-repository-transaction`, `61-ress-loadout-import` |
| P1 prior journal incompatibility | Established schema-1 `backup` writes; strict reading of both established and interim field spellings | Literal prepared/old-moved/published records and malformed staged paths in case 50 |
| P1 inherited package preservation | Failed/partial inventory is unverifiable, not absence; no new installation/removal authority | `71-observation-failure`, including later claim release and preservation |
| P1 unhealthy panel view | Publish only after validated inventory/health and accepted process exits, independent of event order | `72-panel-producer-consumer` uses actual CLI JSON and Service handlers |
| P2 keyboard entry | Every surviving field row activates its TextField | Case 72 executes actual trigger dispatch; rendered focus remains manual |
| P2 Ress parser mismatch | Explicit decision object and bounded decision values | Actual producer payload in case 72; malformed-data Model tests |
| P2 applied composition | Preset starts, additive union, theme retention/conflict and unavailable-source explanations | Model union/conflict tests, actual panel dispatch, QML lint |
| P2 inherited preview provenance | No authoritative provenance or recovery write during dry-run; advisory evidence disclosed separately | `73-preview-migration`, byte checks including interrupted operations |
| P2 silent first-read migration | Shared reporting plus migration facts in each affected consumer result | Case 73 covers catalog, item query/rename, apply, update, Share and Ress; JSON singleton/porcelain checks |
| P2 state directory diagnosis | Distinguish writable files from writable directories | `69-doctor` after apply |

Unused enabled-unit fixtures were removed. Obsolete specification purposes and
command naming were reconciled. Existing shared transaction/read infrastructure,
AUR consent, narrow package removal, claims, Git synchronization and constrained
profiles remain in place; no dependency was added.

## Automated validation

The final complete integration run passed 48 cases and 1,419 assertions in
255 seconds. All 10 targeted audit mutations were caught. The mutation runner
also passed its full baseline (1,410 assertions; its recursive runner self-test
is intentionally suppressed). This was a targeted sweep, not a rerun of all
43 pre-existing mutation detectors.
Strict validation passed all 12 main specifications and this active change.
Structure validation passed 20 modules and 223 function definitions; diff
whitespace checks passed. QML lint and Model tests ran in case 16.

## Review limits and follow-up

The ten reported findings have corrective implementations and focused automated
evidence. No staging, committing, merging, or archive was performed. The new
delta requirements remain in this active change for review and later sync/archive.

The package-observation and dry-run defects predate the removal and should stay
separately identifiable when commits are organized. Existing records that may
already have acquired incorrect package ownership are not silently rewritten;
such state requires explicit review.

No new disposable-VM or rendered validation was run. The user explicitly
deferred these checks on 2026-10-10 to recreate the VMs. Historical VM results
in the testing documentation do not establish evidence for these corrections.
Before merge, verify real
keyboard field entry and focus return, preset composition and theme feedback,
unhealthy Applied Loadouts and Ress inspection, terminal handoffs, and real
package preservation in the disposable Omarchy environment. See
`docs/testing/fresh-machine-validation.md` for the existing procedure.

Filesystem checks enforce observed containment and cooperative publication
locking; they do not claim protection against an unrelated hostile process
racing filesystem replacement. The consumer test executes actual handlers
without treating JavaScript stubs as a rendered UI or real package manager.
