# Status is a local, non-mutating projection with stable severity precedence.

source "$TESTS_DIR/lib/loadout.sh"

seed_machine
machine_publish repo alpha beta

library="$SANDBOX/status-library"
source_profile="$SANDBOX/status-source"
write_package_loadout "$source_profile" "Status Loadout" alpha
mntg repository init "$library" --id status-library --json
assert_ok "status library initializes"
mkdir -p "$library/loadouts/workstation"
cp "$source_profile/profile.json" "$library/loadouts/workstation/profile.json"
git -C "$library" add -A
git -C "$library" commit -q -m initial
mntg repository configure status "$library" --json
assert_ok "status library is configured"
mntg apply --yes status --loadout workstation
assert_ok "status fixture applies"
loadout_id=$(first_loadout_id)

mntg status --json
assert_ok "healthy status is available"
jq -e '.attention == "healthy" and .causes == [] and
  .loadouts.items[0].updateAvailable == false' <<<"$OUT" >/dev/null && _pass ||
  _fail "healthy status has no fabricated update evidence" "$OUT"

# Only an explicit update preview establishes update availability. Merely
# changing the configured checkout does not make an ordinary refresh infer it.
jq '.packages.native=["beta"]' "$library/loadouts/workstation/profile.json" \
  >"$library/loadouts/workstation/next"
mv "$library/loadouts/workstation/next" "$library/loadouts/workstation/profile.json"
git -C "$library" add -A
git -C "$library" commit -q -m changed
mntg status --json
assert_equals "$(jq -r '.attention' <<<"$OUT")" "healthy" \
  "checkout changes alone do not claim an update"
mntg loadout update --dry-run "$loadout_id" status
assert_ok "explicit update preview succeeds"
assert_file "$XDG_STATE_HOME/montage/status-evidence.json" \
  "update preview records bounded advisory evidence"
mntg status --json
assert_equals "$(jq -r '.attention' <<<"$OUT")" "update-available" \
  "explicit changed-content preview establishes update availability"
jq -e --arg id "$loadout_id" '.loadouts.updateAvailable == 1 and
  (.causes | index("update-available")) and
  (.loadouts.items[] | select(.id == $id) | .updateAvailable)' <<<"$OUT" >/dev/null && _pass ||
  _fail "update detail remains attached to the affected loadout" "$OUT"

# Missing is ordinarily repairable and outranks an established update.
: >"$FAKE_STATE/native.txt"
mntg status --json
assert_equals "$(jq -r '.attention' <<<"$OUT")" "repair-needed" \
  "repair-needed outranks update availability"

# Incompatible claim evidence outranks repair-needed while preserving both
# detail causes and the lower-priority update fact.
jq --arg id "$loadout_id" '
  .claims |= map(if .loadoutId == $id then .status="conflicting" |
    .lastError="test conflict" else . end) |
  .loadouts |= map(if .id == $id then .state="conflicting" else . end)
' "$(registry_path)" >"$(registry_path).next"
mv "$(registry_path).next" "$(registry_path)"
mntg status --json
assert_equals "$(jq -r '.attention' <<<"$OUT")" "drifted" \
  "drifted outranks repair-needed"
jq -e '(.causes | index("loadout-drift")) and (.causes | index("update-available"))' \
  <<<"$OUT" >/dev/null && _pass || _fail "status preserves simultaneous causes" "$OUT"

# An interrupted authoritative operation outranks all resource conditions.
jq --arg id "$loadout_id" '.operation={kind:"repair",target:$id,phase:"planned",
  actions:[{resourceId:"package:alpha",state:"planned"}]}' \
  "$(registry_path)" >"$(registry_path).next"
mv "$(registry_path).next" "$(registry_path)"
mntg status --json
assert_equals "$(jq -r '.attention' <<<"$OUT")" "operation-partial-or-failed" \
  "incomplete operation has precedence over drift"

# Return applied state to healthy, then make the configured library unavailable.
printf 'alpha\t1.0-1\n' >"$FAKE_STATE/native.txt"
jq --arg id "$loadout_id" '.operation=null |
  .claims |= map(if .loadoutId == $id then .status="healthy" | .lastError="" else . end) |
  .loadouts |= map(if .id == $id then .state="healthy" else . end)' \
  "$(registry_path)" >"$(registry_path).next"
mv "$(registry_path).next" "$(registry_path)"
repository_registry="$XDG_CONFIG_HOME/montage/repositories.json"
jq '.repositories[0].path="/definitely/missing/status-library"' "$repository_registry" \
  >"$repository_registry.next"
mv "$repository_registry.next" "$repository_registry"
mntg status --json
assert_equals "$(jq -r '.attention' <<<"$OUT")" "repository-attention" \
  "unavailable configured library requests a repository decision"

printf '{malformed\n' >"$XDG_STATE_HOME/montage/status-evidence.json"
mntg status --json
assert_equals "$(jq -r '.attention' <<<"$OUT")" "unavailable-or-invalid" \
  "malformed optional update evidence is not fabricated"
assert_output '"status-evidence-invalid"' \
  "malformed update evidence remains an explicit cause"

# A live lock owner has highest precedence even when lower-level evidence is
# invalid. A syntactically plausible marker without a lock owner is not active.
operation_ready="$SANDBOX/status-operation-ready"
operation_stop="$SANDBOX/status-operation-stop"
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
assert_equals "$(jq -r '.attention' <<<"$OUT")" "operation-active" \
  "live operation owner has highest precedence"
: >"$operation_stop"
wait "$operation_pid"
mntg status --json
assert_equals "$(jq -r '.attention' <<<"$OUT")" "unavailable-or-invalid" \
  "stale marker is invalid rather than active"
rm -f "$XDG_STATE_HOME/montage/running"

# Return to valid state and prove ordinary refresh changes no owned file or Git
# checkout and invokes no network or mutation command double.
rm -f "$XDG_STATE_HOME/montage/status-evidence.json"
jq --arg path "$library" '.repositories[0].path=$path' "$repository_registry" \
  >"$repository_registry.next"
mv "$repository_registry.next" "$repository_registry"
before_files=$(find "$XDG_CONFIG_HOME/montage" "$XDG_STATE_HOME/montage" -type f \
  -printf '%p %s %T@\n' | sort)
before_head=$(git -C "$library" rev-parse HEAD)
before_tree=$(git -C "$library" status --porcelain=v1 --untracked-files=all)
: >"$CALLS"
mntg status --json
assert_ok "ordinary local status succeeds"
after_files=$(find "$XDG_CONFIG_HOME/montage" "$XDG_STATE_HOME/montage" -type f \
  -printf '%p %s %T@\n' | sort)
assert_equals "$after_files" "$before_files" "ordinary status writes no owned file"
assert_equals "$(git -C "$library" rev-parse HEAD)" "$before_head" \
  "ordinary status does not move repository history"
assert_equals "$(git -C "$library" status --porcelain=v1 --untracked-files=all)" "$before_tree" \
  "ordinary status does not change repository content"
assert_not_called "git fetch" "ordinary status performs no fetch"
assert_not_called "git pull" "ordinary status performs no pull"
assert_not_called "git push" "ordinary status performs no push"
assert_not_called "pacman -S" "ordinary status performs no repair or apply"
