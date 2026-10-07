source "$TESTS_DIR/lib/loadout.sh"

seed_machine
packages=()
for i in $(seq -w 1 50); do packages+=("scale-$i"); done
machine_install native "${packages[@]}"
machine_publish repo "${packages[@]}"

P10="$SANDBOX/scale-10"
P50="$SANDBOX/scale-50"
write_package_loadout "$P10" Scale-10 "${packages[@]:0:10}"
write_package_loadout "$P50" Scale-50 "${packages[@]}"
export MONTAGE_OBSERVATION_LOG="$SANDBOX/observations.log"
REAL_JQ=$(command -v jq)
COUNT_BIN="$SANDBOX/count-bin"
mkdir -p "$COUNT_BIN"
printf '%s\n' '#!/bin/bash' \
  'printf "jq\\n" >>"$CALLS"' \
  'exec "$MONTAGE_REAL_JQ" "$@"' >"$COUNT_BIN/jq"
chmod +x "$COUNT_BIN/jq"
export MONTAGE_REAL_JQ="$REAL_JQ"
export PATH="$COUNT_BIN:$PATH"

run_counted() {
  : >"$CALLS"
  : >"$MONTAGE_OBSERVATION_LOG"
  mntg "$@"
  PACMAN_INVENTORIES=$(grep -c '^pacman -Qq$' "$CALLS" 2>/dev/null || true)
  JQ_CALLS=$(grep -c '^jq$' "$CALLS" 2>/dev/null || true)
  PACKAGE_SNAPSHOTS=$(grep -c '^package-inventory$' "$MONTAGE_OBSERVATION_LOG" 2>/dev/null || true)
  THEME_SNAPSHOTS=$(grep -c '^active-theme$' "$MONTAGE_OBSERVATION_LOG" 2>/dev/null || true)
  REGISTRY_INDEXES=$(grep -c '^registry-index$' "$MONTAGE_OBSERVATION_LOG" 2>/dev/null || true)
}

run_counted apply --dry-run "$P10"
assert_ok "the 10-resource human plan succeeds"
assert_equals "$(grep -c '^  PROTECT  package:scale-' <<<"$OUT")" "10" "the human plan contains every resource"
assert_equals "$PACMAN_INVENTORIES" "1" "10 resources use one package inventory"
assert_equals "$PACKAGE_SNAPSHOTS" "1" "10 resources build one package snapshot"
assert_equals "$THEME_SNAPSHOTS" "1" "10 resources build one active-theme snapshot"
assert_equals "$REGISTRY_INDEXES" "1" "10 resources build one registry index"
jq_10=$JQ_CALLS

run_counted apply --dry-run --porcelain "$P50"
assert_ok "the 50-resource porcelain plan succeeds"
assert_equals "$(grep -c '^LOG|plan: PROTECT package:scale-' <<<"$OUT")" "50" "the porcelain plan contains every resource"
assert_equals "$PACMAN_INVENTORIES" "1" "50 resources still use one package inventory"
assert_equals "$PACKAGE_SNAPSHOTS" "1" "50 resources still build one package snapshot"
assert_equals "$THEME_SNAPSHOTS" "1" "50 resources still build one active-theme snapshot"
assert_equals "$REGISTRY_INDEXES" "1" "50 resources still build one registry index"
if (( JQ_CALLS <= jq_10 * 5 + 30 )); then _pass
else _fail "jq assembly should grow linearly: 10=$jq_10, 50=$JQ_CALLS"; fi

run_counted apply --yes "$P10"
assert_ok "the representative loadout is tracked"
ID=$(first_loadout_id)
run_counted loadout check "$ID" --json
assert_ok "the batched JSON check remains healthy"
assert_equals "$(jq -r '.loadouts[0].resources | length' <<<"$OUT")" "10" "JSON check returns every resource"
assert_equals "$(jq -r '.healthy' <<<"$OUT")" "true" "JSON check preserves health semantics"
assert_equals "$PACMAN_INVENTORIES" "1" "check uses one package inventory"
assert_equals "$PACKAGE_SNAPSHOTS" "1" "check uses one package snapshot"
assert_equals "$THEME_SNAPSHOTS" "1" "check uses one theme snapshot"
assert_equals "$REGISTRY_INDEXES" "1" "check uses one registry index"
