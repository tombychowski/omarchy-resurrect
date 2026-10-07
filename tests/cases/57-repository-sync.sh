# Fetch-only inspection classifies repository relationships without changing
# the checkout, index, working tree, or either side's content.

declare -A ROOTS=()
declare -A REMOTES=()

make_sync_fixture() {
  local name="$1" root remote
  root="$SANDBOX/$name"
  remote="$SANDBOX/$name.git"
  mntg repository init loadouts "$root" --id "$name" >/dev/null
  git clone -q --bare "$root" "$remote"
  git -C "$root" config "url.file://$remote.insteadOf" "https://sync.example/$name"
  mntg repository configure "$name" "$root" loadouts \
    --remote "https://sync.example/$name" >/dev/null
  ROOTS[$name]="$root"
  REMOTES[$name]="$remote"
}

assert_sync_state() {
  local name="$1" expected="$2" root="${ROOTS[$1]}" before_head before_status
  before_head=$(git -C "$root" rev-parse HEAD)
  before_status=$(git -C "$root" status --porcelain=v1 --untracked-files=all)
  mntg repository sync "$name" --json
  assert_ok "$name synchronization inspection"
  assert_equals "$(jq -r '.status' <<<"$OUT")" "$expected" "$name relationship"
  assert_equals "$(git -C "$root" rev-parse HEAD)" "$before_head" \
    "$name inspection leaves checkout selected"
  assert_equals "$(git -C "$root" status --porcelain=v1 --untracked-files=all)" "$before_status" \
    "$name inspection leaves repository content clean"
}

make_sync_fixture equal
assert_sync_state equal equal
assert_equals "$(jq -r '.ahead' <<<"$OUT")" "0" "equal has no ahead commits"
assert_equals "$(jq -r '.behind' <<<"$OUT")" "0" "equal has no behind commits"
assert_equals "$(jq -r '.action.performed' <<<"$OUT")" "fetch" \
  "preview reports its fetch-only action"

mntg repository sync equal --pull --json
assert_ok "an explicit pull of equal history succeeds as a no-op"
assert_equals "$(jq -r '.action.performed' <<<"$OUT")" "no-op" \
  "equal history reports a successful no-op"
assert_equals "$(jq -r '.action.ok' <<<"$OUT")" "true" \
  "equal no-op is a successful synchronization result"

mntg repository sync equal --pull
assert_ok "human output reports a successful no-op"
assert_output "action:  no-op (ok)" "human mode names the completed synchronization action"

mntg --porcelain repository sync equal
assert_ok "porcelain preview succeeds"
assert_output "BEGIN|sync|equal|loadouts" "porcelain identifies the loadout repository"
assert_output "SYNC|1|equal|0|0|true|fetch|true|" \
  "porcelain carries the versioned fetch-only result"
assert_output "DONE|ok|synchronization complete" "porcelain preview has one terminal record"
assert_no_output "{" "porcelain synchronization output contains no JSON or prose"

make_sync_fixture local-ahead
printf 'local\n' >"${ROOTS[local-ahead]}/local-note"
git -C "${ROOTS[local-ahead]}" add local-note
git -C "${ROOTS[local-ahead]}" commit -q -m local
assert_sync_state local-ahead local-ahead
assert_equals "$(jq -r '.ahead' <<<"$OUT")" "1" "local-ahead count"
assert_equals "$(jq -r '.behind' <<<"$OUT")" "0" "local-ahead has no remote-only commit"

make_sync_fixture remote-ahead
remote_work="$SANDBOX/remote-ahead-work"
git clone -q "${REMOTES[remote-ahead]}" "$remote_work"
printf 'remote\n' >"$remote_work/remote-note"
git -C "$remote_work" add remote-note
git -C "$remote_work" commit -q -m remote
git -C "$remote_work" push -q origin main
assert_sync_state remote-ahead remote-ahead
assert_equals "$(jq -r '.ahead' <<<"$OUT")" "0" "remote-ahead has no local-only commit"
assert_equals "$(jq -r '.behind' <<<"$OUT")" "1" "remote-ahead count"

make_sync_fixture divergent
printf 'local\n' >"${ROOTS[divergent]}/local-note"
git -C "${ROOTS[divergent]}" add local-note
git -C "${ROOTS[divergent]}" commit -q -m local
divergent_work="$SANDBOX/divergent-work"
git clone -q "${REMOTES[divergent]}" "$divergent_work"
printf 'remote\n' >"$divergent_work/remote-note"
git -C "$divergent_work" add remote-note
git -C "$divergent_work" commit -q -m remote
git -C "$divergent_work" push -q origin main
assert_sync_state divergent divergent
assert_equals "$(jq -r '.ahead' <<<"$OUT")" "1" "divergence reports local-only history"
assert_equals "$(jq -r '.behind' <<<"$OUT")" "1" "divergence reports remote-only history"

make_sync_fixture fetch-failure
git -C "${ROOTS[fetch-failure]}" config --unset-all \
  "url.file://${REMOTES[fetch-failure]}.insteadOf"
git -C "${ROOTS[fetch-failure]}" config \
  "url.file://$SANDBOX/missing.git.insteadOf" "https://sync.example/fetch-failure"
before=$(git -C "${ROOTS[fetch-failure]}" rev-parse HEAD)
mntg repository sync fetch-failure --json
assert_fails "fetch or authentication failure is explicit"
assert_equals "$(jq -r '.status' <<<"$OUT")" "fetch-failed" \
  "failed fetch has a stable classification"
assert_equals "$(jq -r '.fetch.errorCode' <<<"$OUT")" "fetch-failed" \
  "failed fetch has a machine-readable reason"
assert_equals "$(git -C "${ROOTS[fetch-failure]}" rev-parse HEAD)" "$before" \
  "failed fetch does not move local history"

mntg repository sync divergent
assert_ok "human synchronization classification"
assert_output "divergent  ahead 1  behind 1"

# Explicit actions preserve both known histories and never guess at divergence.
local_ahead_head=$(git -C "${ROOTS[local-ahead]}" rev-parse HEAD)
mntg repository sync local-ahead --push --json
assert_ok "ordinary push of local-ahead history"
assert_equals "$(jq -r '.action.performed' <<<"$OUT")" "push" \
  "push result names the action"
assert_equals "$(git --git-dir="${REMOTES[local-ahead]}" rev-parse refs/heads/main)" \
  "$local_ahead_head" "ordinary push advances the remote"

remote_ahead_head=$(git --git-dir="${REMOTES[remote-ahead]}" rev-parse refs/heads/main)
mntg repository sync remote-ahead --pull --json
assert_ok "fast-forward pull of remote-ahead history"
assert_equals "$(jq -r '.action.performed' <<<"$OUT")" "fast-forward-pull" \
  "pull result names the history-preserving action"
assert_equals "$(git -C "${ROOTS[remote-ahead]}" rev-parse HEAD)" "$remote_ahead_head" \
  "fast-forward pull advances local history"

divergent_local=$(git -C "${ROOTS[divergent]}" rev-parse HEAD)
divergent_remote=$(git --git-dir="${REMOTES[divergent]}" rev-parse refs/heads/main)
mntg repository sync divergent --pull --json
assert_fails "divergence requires a user decision"
assert_equals "$(jq -r '.action.performed' <<<"$OUT")" "decision-required" \
  "divergence is not reported as success"
assert_equals "$(git -C "${ROOTS[divergent]}" rev-parse HEAD)" "$divergent_local" \
  "divergent pull leaves local history unchanged"
assert_equals "$(git --git-dir="${REMOTES[divergent]}" rev-parse refs/heads/main)" \
  "$divergent_remote" "divergent pull leaves remote history unchanged"

mntg --porcelain repository sync divergent --pull
assert_fails "porcelain divergence is not false success"
assert_output "SYNC|1|divergent|1|1|true|decision-required|false|divergent-history" \
  "porcelain reports the exact divergent decision boundary"
assert_output "DONE|decision|required" "porcelain divergence requires a decision"

make_sync_fixture push-failure
printf 'local\n' >"${ROOTS[push-failure]}/local-note"
git -C "${ROOTS[push-failure]}" add local-note
git -C "${ROOTS[push-failure]}" commit -q -m local
printf '#!/bin/sh\nexit 1\n' >"${REMOTES[push-failure]}/hooks/pre-receive"
chmod +x "${REMOTES[push-failure]}/hooks/pre-receive"
failed_local=$(git -C "${ROOTS[push-failure]}" rev-parse HEAD)
failed_remote=$(git --git-dir="${REMOTES[push-failure]}" rev-parse refs/heads/main)
mntg repository sync push-failure --push --json
assert_fails "a rejected push is not false success"
assert_equals "$(jq -r '.action.reason' <<<"$OUT")" "push-failed" \
  "push rejection is explicit"
assert_equals "$(git -C "${ROOTS[push-failure]}" rev-parse HEAD)" "$failed_local" \
  "push failure preserves local history"
assert_equals "$(git --git-dir="${REMOTES[push-failure]}" rev-parse refs/heads/main)" \
  "$failed_remote" "push failure preserves remote history"

mntg --porcelain repository sync push-failure --push
assert_fails "porcelain does not hide a rejected push"
assert_output "SYNC|1|local-ahead|1|0|true|failed|false|push-failed" \
  "porcelain carries the partial push failure"
assert_output "DONE|fail|synchronization failed" "partial failure has a failure terminal record"
assert_no_output "{" "failed porcelain synchronization remains prose-free"

# The same versioned protocol applies to native vault repositories.
vault_root=$(make_vault "$SANDBOX/sync-vault")
seal_vault "$vault_root" sync-vault
vault_id=$(jq -r '.id' "$vault_root/montage.json")
vault_remote="$SANDBOX/sync-vault.git"
git clone -q --bare "$vault_root" "$vault_remote"
git -C "$vault_root" config "url.file://$vault_remote.insteadOf" \
  "https://sync.example/sync-vault"
mntg repository configure sync-vault "$vault_root" vault \
  --remote "https://sync.example/sync-vault" >/dev/null
mntg repository sync sync-vault --json
assert_ok "vault repository synchronization uses the JSON protocol"
assert_equals "$(jq -r '.repositoryType' <<<"$OUT")" "vault" \
  "JSON identifies the vault repository kind"
assert_equals "$(jq -r '.repositoryId' <<<"$OUT")" "$vault_id" \
  "vault sync carries stable repository identity"
mntg --porcelain repository sync sync-vault
assert_ok "vault repository synchronization uses the porcelain protocol"
assert_output "BEGIN|sync|$vault_id|vault" \
  "porcelain identifies the native vault repository"
assert_output "SYNC|1|equal|0|0|true|fetch|true|" \
  "vault porcelain result uses the same versioned schema"

# Credential refusal is tested at the classifier boundary because the registry
# correctly refuses to persist such an entry in the first place.
PLUGIN_DIR="$REPO_DIR"
source "$REPO_DIR/lib/montage/core.sh"
source "$REPO_DIR/lib/montage/safety.sh"
source "$REPO_DIR/lib/montage/repository/sync.sh"
credential_entry=$(jq -nc --arg path "${ROOTS[equal]}" \
  '{name:"credential-test",path:$path,type:"loadouts",id:"equal",
    remote:"https://token@example.invalid/repository.git"}')
if repository_sync_classify "$credential_entry"; then STATUS=0; else STATUS=$?; fi
OUT="$REPOSITORY_SYNC_RESULT"
assert_fails "synchronization refuses a credential-bearing remote"
assert_equals "$(jq -r '.status' <<<"$OUT")" "invalid-remote" \
  "credential refusal is versioned and machine-readable"
assert_equals "$(jq -r '.fetch.errorCode' <<<"$OUT")" "invalid-remote" \
  "credential refusal has a stable error code"
assert_no_output "token@" "credential material is not reflected in synchronization output"

assert_file_lacks "$REPO_DIR/lib/montage/repository/sync.sh" "--force" \
  "sync implementation contains no force option"
assert_file_lacks "$REPO_DIR/lib/montage/repository/sync.sh" " reset " \
  "sync implementation contains no reset operation"
assert_file_contains "$REPO_DIR/lib/montage/repository/sync.sh" "merge -q --ff-only" \
  "the only integration action is an explicit fast-forward"
