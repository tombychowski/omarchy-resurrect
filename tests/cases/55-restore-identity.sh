# Preview, verification, confirmation and resume state bind to repository id
# plus one immutable backup commit rather than a moving branch or timestamp.

VAULT=$(make_vault "$SANDBOX/history-vault")
printf 'alpha\n' >"$VAULT/packages/native.txt"
seal_vault "$VAULT" lineage
first=$(git -C "$VAULT" rev-parse HEAD)
repository_id=$(jq -r '.id' "$VAULT/montage.json")

printf 'beta\n' >"$VAULT/packages/native.txt"
jq '.createdAt = "2026-02-01T00:00:00Z"' "$VAULT/backup.json" >"$VAULT/x"
mv "$VAULT/x" "$VAULT/backup.json"
git -C "$VAULT" add -A
git -C "$VAULT" commit -q -m second
second=$(git -C "$VAULT" rev-parse HEAD)
machine_publish repo alpha beta gamma

mntg --vault "$VAULT" restore --backup "$first" --dry-run --only packages
assert_ok "exact historical restore preview"
assert_output "Previewing backup ${first:0:12} from vault $repository_id"
assert_output "alpha"
assert_no_output "beta" "preview does not drift to HEAD"
assert_no_file "$XDG_STATE_HOME/montage/restore.state" "dry run records no resume state"

mntg --vault "$VAULT" verify --backup "$first" --json
assert_fails "verification reports the historical package missing"
assert_equals "$(jq -r '.repositoryId' <<<"$OUT")" "$repository_id" \
  "verification reports the selected repository identity"
assert_equals "$(jq -r '.backupCommit' <<<"$OUT")" "$first" \
  "verification reports the selected exact commit"

montage_answer "n" -- --vault "$VAULT" restore --backup "$first" --only packages
assert_fails "declining exact restore confirmation cancels"
assert_output "Restore backup ${first:0:12} from vault $repository_id?"
assert_not_called "pacman -S" "declined confirmation performs no package mutation"

# Resolve HEAD as the second commit, then move the branch before preview. The
# isolated selected tree and its identity remain the second commit.
: >"$CALLS"
MONTAGE_TEST_MOVE_VAULT_HEAD_TO="$first" \
  mntg --vault "$VAULT" restore --yes --only packages
assert_ok "restore survives mutable-selector drift"
assert_output "Restoring backup ${second:0:12} from vault $repository_id"
assert_called "pacman -S --needed --noconfirm -- beta" \
  "restore uses the content selected before the branch moved"
assert_not_called "pacman -S --needed --noconfirm -- alpha" \
  "restore does not follow the moved branch"
assert_equals "$(head -1 "$XDG_STATE_HOME/montage/restore.state")" \
  "# $repository_id $second" \
  "resume progress stores repository id and immutable commit"

git -C "$VAULT" reset -q --hard "$second"
: >"$CALLS"
mntg --vault "$VAULT" restore --yes --backup "$second" --only packages
assert_output "already done" "the same repository and commit resume completed work"
assert_not_called "pacman -S" "resumed completed work is not repeated"

: >"$CALLS"
mntg --vault "$VAULT" restore --yes --backup "$first" --only packages
assert_no_output "already done" "another commit never reuses prior progress"
assert_called "pacman -S --needed --noconfirm -- alpha"
assert_equals "$(head -1 "$XDG_STATE_HOME/montage/restore.state")" \
  "# $repository_id $first" \
  "progress advances to the newly selected commit"

OTHER=$(make_vault "$SANDBOX/other-vault")
printf 'gamma\n' >"$OTHER/packages/native.txt"
seal_vault "$OTHER" other
other_id=$(jq -r '.id' "$OTHER/montage.json")
other_commit=$(git -C "$OTHER" rev-parse HEAD)
: >"$CALLS"
mntg --vault "$OTHER" restore --yes --only packages
assert_no_output "already done" "another repository never reuses prior progress"
assert_called "pacman -S --needed --noconfirm -- gamma"
assert_equals "$(head -1 "$XDG_STATE_HOME/montage/restore.state")" \
  "# $other_id $other_commit" \
  "progress binds the replacement repository and commit"
