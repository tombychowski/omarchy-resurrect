# Loadout-only consumer protocols stay parseable and expose stable attention.

source "$TESTS_DIR/lib/loadout.sh"

assert_json_document() {
  jq -e . <<<"$OUT" >/dev/null 2>&1 && _pass || _fail "$1 is one JSON document" "$OUT"
}

mntg status --json
assert_ok "empty loadout status succeeds"
assert_json_document "status"
assert_equals "$(jq -r '.kind' <<<"$OUT")" "montage-status" "status kind"
assert_equals "$(jq -r '.attention' <<<"$OUT")" "healthy" "valid empty state is healthy"
assert_equals "$(jq -r '.loadouts.count' <<<"$OUT")" "0" "empty status has zero loadouts"
assert_equals "$(jq -r '.repositories.count' <<<"$OUT")" "0" "empty status has zero libraries"
assert_equals "$(jq -r 'has("hasVault") or has("lastBackup") or has("categories")' <<<"$OUT")" \
  "false" "status contains no backup fields"

mntg --porcelain status
assert_ok "status porcelain succeeds"
bad=$(printf '%s\n' "$OUT" | grep -vE '^(BEGIN|MIGRATION|STATUS|DONE)\|' | grep -c . || true)
assert_equals "$bad" "0" "status porcelain contains only documented records"
assert_output "STATUS|1|healthy|0|0" "status porcelain carries attention and counts"

library="$SANDBOX/protocol-library"
mntg repository init "$library" --id protocol-library --json
assert_ok "repository init JSON succeeds"
assert_json_document "repository init"
mntg repository configure protocol "$library" --json
assert_ok "repository configure JSON succeeds"
assert_json_document "repository configure"
mntg repository list --json
assert_ok "repository list JSON succeeds"
assert_json_document "repository list"

mntg loadout list --json
assert_ok "loadout list JSON succeeds"
assert_json_document "loadout list"
mntg resource list --json
assert_ok "resource list JSON succeeds"
assert_json_document "resource list"

mkdir -p "$XDG_STATE_HOME/montage"
printf 'not json\n' >"$XDG_STATE_HOME/montage/loadouts.json"
mntg status --json
assert_ok "malformed optional applied state still emits status"
assert_json_document "invalid applied status"
assert_equals "$(jq -r '.attention' <<<"$OUT")" "unavailable-or-invalid" \
  "malformed applied state is unavailable"
assert_equals "$(jq -r '.loadouts.available' <<<"$OUT")" "false" \
  "malformed applied state is not fabricated as empty"

rm -f "$XDG_STATE_HOME/montage/loadouts.json"
operation_ready="$SANDBOX/operation-ready"
operation_stop="$SANDBOX/operation-stop"
(
  exec 9>"$XDG_STATE_HOME/montage/lock"
  flock 9
  printf '%s:456:789\n' "$BASHPID" >"$XDG_STATE_HOME/montage/running"
  : >"$operation_ready"
  while [[ ! -e $operation_stop ]]; do read -r -t 0.05 _ || true; done
) &
operation_pid=$!
while [[ ! -e $operation_ready ]]; do read -r -t 0.05 _ || true; done
mntg status --json
assert_ok "active status succeeds"
assert_json_document "active status"
assert_equals "$(jq -r '.attention' <<<"$OUT")" "operation-active" "active operation has precedence"
: >"$operation_stop"
wait "$operation_pid"
rm -f "$XDG_STATE_HOME/montage/running"

# Every stable classification belongs to the versioned status vocabulary even
# when a particular state needs richer lifecycle fixtures later in the suite.
for state in healthy drifted repair-needed update-available repository-attention \
  operation-active operation-partial-or-failed unavailable-or-invalid; do
  rg -q --fixed-strings "$state" "$REPO_DIR/lib/montage/commands.sh" && _pass ||
    _fail "status implementation recognizes $state"
done
