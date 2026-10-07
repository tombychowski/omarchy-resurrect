#!/bin/bash
#
# Restore progress/journal state and partial-result bookkeeping.
# Depends on core.sh. Used by restore category replay and orchestration.
# Definitions only at source time.

RESTORE_STATE=""
RESTORE_FAILED=0
FAILED_STEPS=()
PARTIAL_STEPS=()

# Set by cmd_restore. Empty leaves the decision to the persisted settings.
UNITS_CHOICE=""
FIRST_CONTACT=0

step_done() { grep -qxF "$1" "$RESTORE_STATE" 2>/dev/null; }
mark_done() { printf '%s\n' "$1" >>"$RESTORE_STATE"; }

mark_partial() {
  local category="$1" reason="$2" existing
  for existing in "${PARTIAL_STEPS[@]:-}"; do
    [[ $existing == "$category|"* ]] && return 0
  done
  PARTIAL_STEPS+=("$category|$reason")
}

was_partial() {
  local entry
  for entry in "${PARTIAL_STEPS[@]:-}"; do
    [[ $entry == "$1|"* ]] && return 0
  done
  return 1
}
