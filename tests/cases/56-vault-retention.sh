# Labels are stable selectors and protect history from implicit retention.
# Retention is previewed, confirmed, local-only, and reports remote divergence.

VAULT=$(make_vault "$SANDBOX/retention-vault")
printf 'one\n' >"$VAULT/packages/native.txt"
seal_vault "$VAULT" retention
commits=("$(git -C "$VAULT" rev-parse HEAD)")
for number in 2 3 4; do
  printf 'package-%s\n' "$number" >"$VAULT/packages/native.txt"
  jq --arg created "2026-0${number}-01T00:00:00Z" '.createdAt = $created' \
    "$VAULT/backup.json" >"$VAULT/x"
  mv "$VAULT/x" "$VAULT/backup.json"
  git -C "$VAULT" add -A
  git -C "$VAULT" commit -q -m "backup $number"
  commits+=("$(git -C "$VAULT" rev-parse HEAD)")
done

REMOTE="$SANDBOX/retention-remote.git"
git clone -q --bare "$VAULT" "$REMOTE"
git -C "$VAULT" remote add origin "$REMOTE"
git -C "$VAULT" push -q -u origin main

mntg --vault "$VAULT" backup label archive-point "${commits[0]}" --json
assert_ok "label an exact backup"
assert_equals "$(jq -r '.label' <<<"$OUT")" "archive-point" \
  "label result reports the stable selector"
mntg --vault "$VAULT" backup label current "${commits[3]}" >/dev/null
assert_ok "label a retained backup"

mntg --vault "$VAULT" backup label archive-point "${commits[1]}"
assert_fails "labels are unique"
assert_output "already exists"
mntg --vault "$VAULT" backup label 'Bad Label' "${commits[1]}"
assert_fails "unsafe labels are rejected"

mntg --vault "$VAULT" backup show archive-point --json
assert_ok "show resolves a managed label"
assert_equals "$(jq -r '.backup.commit' <<<"$OUT")" "${commits[0]}" \
  "label resolves to its exact commit"
assert_equals "$(jq -r '.backup.label' <<<"$OUT")" "archive-point" \
  "history metadata reports the label"

head_before=$(git -C "$VAULT" rev-parse HEAD)
mntg --dry-run --vault "$VAULT" backup retain --keep 2 --json
assert_fails "a label protects history selected for removal"
assert_equals "$(jq -r '.blocked' <<<"$OUT")" "true" \
  "retention plan reports its blocked state"
assert_equals "$(jq -r '.protectedLabels[0].label' <<<"$OUT")" "archive-point" \
  "retention names the protecting label"
assert_equals "$(git -C "$VAULT" rev-parse HEAD)" "$head_before" \
  "blocked retention does not move history"

mntg --vault "$VAULT" backup unlabel archive-point --json
assert_ok "remove a protection label explicitly"
assert_equals "$(jq -r '.commit' <<<"$OUT")" "${commits[0]}" \
  "unlabel reports the formerly protected commit"

mntg --dry-run --vault "$VAULT" backup retain --keep 2 --json
assert_ok "retention dry run"
assert_equals "$(jq -r '.removed | length' <<<"$OUT")" "2" \
  "preview names exactly the older backups"
assert_equals "$(jq -r '.remoteDivergence' <<<"$OUT")" "true" \
  "preview warns that published history would diverge"
assert_equals "$(git -C "$VAULT" rev-parse HEAD)" "$head_before" \
  "dry run does not move history"

montage_answer "n" -- --vault "$VAULT" backup retain --keep 2
assert_fails "retention cancellation"
assert_output "Rewrite local vault history exactly as previewed?"
assert_equals "$(git -C "$VAULT" rev-parse HEAD)" "$head_before" \
  "cancellation preserves history"

mntg --yes --vault "$VAULT" backup retain --keep 2
assert_ok "confirmed retention"
assert_output "local history now diverges from the published remote"
new_head=$(git -C "$VAULT" rev-parse HEAD)
[[ $new_head != "$head_before" ]] && _pass || _fail "retention rewrites the local branch"
git -C "$VAULT" merge-base --is-ancestor "${commits[0]}" HEAD >/dev/null 2>&1
STATUS=$?
assert_fails "removed backup is no longer in local branch history"
assert_equals "$(git -C "$VAULT" rev-list --count HEAD)" "2" \
  "confirmed retention keeps the requested number of backups"
assert_equals "$(git -C "$VAULT" rev-parse refs/remotes/origin/main)" "$head_before" \
  "retention does not rewrite the published remote-tracking history"

mntg --vault "$VAULT" backup show current --json
assert_ok "retained labels are remapped"
assert_equals "$(jq -r '.backup.commit' <<<"$OUT")" "$new_head" \
  "retained label follows the rewritten equivalent backup"
assert_equals "$(git -C "$VAULT" status --porcelain=v1 --untracked-files=all)" "" \
  "retention leaves the checkout clean"
