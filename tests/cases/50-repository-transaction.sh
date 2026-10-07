# Repository mutations serialize, stage on the same filesystem, recover from
# interruption, and create Git commits only for content changes.

PLUGIN_DIR="$REPO_DIR"
source "$REPO_DIR/lib/montage/core.sh"
source "$REPO_DIR/lib/montage/safety.sh"
source "$REPO_DIR/lib/montage/repository/common.sh"
source "$REPO_DIR/lib/montage/repository/transaction.sh"
OUT=""

repo="$SANDBOX/repository"
mkdir -p "$repo/items/current"
repository_envelope_json loadouts transaction-repo "2026-10-06T20:00:00Z" >"$repo/montage.json"
printf 'old\n' >"$repo/items/current/value"
git -C "$repo" init -q -b main
git -C "$repo" add -A
git -C "$repo" commit -q -m initial

repository_worktree_clean "$repo"; STATUS=$?
assert_ok "a committed repository is clean"
printf 'dirty\n' >>"$repo/items/current/value"
repository_worktree_clean "$repo"; STATUS=$?
assert_fails "a dirty worktree is refused"
git -C "$repo" checkout -q -- items/current/value

held="$SANDBOX/lock-held"
(
  repository_lock "$repo" || exit 1
  : >"$held"
  sleep 1
  repository_unlock
) &
holder=$!
while [[ ! -e $held ]]; do sleep 0.02; done
(
  REPOSITORY_LOCK_FD=""
  repository_lock "$repo"
); STATUS=$?
assert_fails "a concurrent repository lock is refused"
wait "$holder"
repository_lock "$repo"; STATUS=$?
assert_ok "the repository lock is available after its owner exits"
repository_unlock

valid_staged() { [[ -f $1/value ]] && grep -qxF new "$1/value"; }
repository_stage_dir "$repo"
stage="$REPOSITORY_STAGE"
printf 'new\n' >"$stage/value"
repository_publish_path "$repo" "$stage" items/current valid_staged; STATUS=$?
assert_ok "a validated staged directory publishes atomically"
assert_file_contains "$repo/items/current/value" "new" "the new directory is installed"
assert_no_file "$(repository_journal_path "$repo")" "successful publication removes its journal"

repository_commit_if_changed "$repo" "update item"; STATUS=$?
assert_ok "a content-changing publication commits"
assert_equals "$REPOSITORY_COMMIT_CHANGED" "1" "content change is reported"
commit_count=$(git -C "$repo" rev-list --count HEAD)
repository_commit_if_changed "$repo" "no-op"; STATUS=$?
assert_ok "a no-op commit request succeeds"
assert_equals "$REPOSITORY_COMMIT_CHANGED" "0" "no-op is reported without a commit"
assert_equals "$(git -C "$repo" rev-list --count HEAD)" "$commit_count" \
  "no-op does not manufacture history"

# Validation happens before the destination or journal changes.
repository_stage_dir "$repo"
stage="$REPOSITORY_STAGE"
printf 'invalid\n' >"$stage/value"
before=$(sha256sum "$repo/items/current/value")
repository_publish_path "$repo" "$stage" items/current valid_staged; STATUS=$?
assert_fails "failed staged validation refuses publication"
assert_equals "$(sha256sum "$repo/items/current/value")" "$before" \
  "failed validation preserves the destination"
assert_no_file "$(repository_journal_path "$repo")" "failed validation creates no journal"
rm -rf "$stage"

# Interruption after the prior destination moves leaves an explicit journal.
repository_stage_dir "$repo"
stage="$REPOSITORY_STAGE"
printf 'newer\n' >"$stage/value"
valid_newer() { [[ -f $1/value ]] && grep -qxF newer "$1/value"; }
MONTAGE_TEST_INTERRUPT_AFTER_OLD_MOVE=1 \
  repository_publish_path "$repo" "$stage" items/current valid_newer; STATUS=$?
assert_exit 75 "the interruption fixture stops after moving the old destination"
assert_no_file "$repo/items/current/value" "interrupted publication is visibly incomplete"
assert_file "$(repository_journal_path "$repo")" "interrupted publication leaves a journal"
repository_recover_publication "$repo"; STATUS=$?
assert_ok "journal recovery restores the prior destination"
assert_file_contains "$repo/items/current/value" "new" "recovery restores old content"
assert_no_file "$(repository_journal_path "$repo")" "recovery removes the journal"
repository_worktree_clean "$repo"; STATUS=$?
assert_ok "recovery returns the repository to its committed clean state"
