# Backup history is read from exact validated commits without moving checkout.

seed_machine
mntg init >/dev/null
VAULT="$XDG_DATA_HOME/montage/vault"
mntg backup -m first >/dev/null
first=$(git -C "$VAULT" rev-parse HEAD)
printf '\n# second snapshot\n' >>"$HOME/.bashrc"
mntg backup -m second >/dev/null
second=$(git -C "$VAULT" rev-parse HEAD)
checkout_before=$(git -C "$VAULT" rev-parse HEAD)
status_before=$(git -C "$VAULT" status --porcelain=v1 --untracked-files=all)

mntg backup list --json
assert_ok "backup list JSON"
assert_equals "$(jq -r '.kind' <<<"$OUT")" "montage-backup-list" \
  "list output has a versioned kind"
assert_equals "$(jq -r '.backups | length' <<<"$OUT")" "2" \
  "list reports both backup commits"
assert_equals "$(jq -r '.backups[0].commit' <<<"$OUT")" "$second" \
  "newest backup is listed first by exact commit"
assert_equals "$(jq -r '.backups[1].commit' <<<"$OUT")" "$first" \
  "older backup retains its exact commit identity"
assert_equals "$(jq -r '.backups[0].sourceMachine.hostname' <<<"$OUT")" "$(hostname)" \
  "history includes source machine evidence"

mntg backup show "$first" --json
assert_ok "show exact backup JSON"
assert_equals "$(jq -r '.kind' <<<"$OUT")" "montage-backup-show" \
  "show output has a versioned kind"
assert_equals "$(jq -r '.backup.commit' <<<"$OUT")" "$first" \
  "show resolves the selected immutable commit"
assert_equals "$(jq -r '.backup.subject' <<<"$OUT")" "first" \
  "show reports commit metadata"
assert_equals "$(jq -r '.backup.counts.packages' <<<"$OUT")" "3" \
  "show reports validated backup counts"

mntg backup list
assert_ok "human backup list"
assert_output "Backups for vault"
assert_output "${first:0:12}"
mntg backup show "$second"
assert_ok "human backup show"
assert_output "machine id:"
assert_equals "$(git -C "$VAULT" rev-parse HEAD)" "$checkout_before" \
  "history queries do not change the checkout"
assert_equals "$(git -C "$VAULT" status --porcelain=v1 --untracked-files=all)" "$status_before" \
  "history queries do not dirty the working tree"

invalid_history_case() {
  local name="$1" mutation="$2" fixture commit
  fixture=$(make_vault "$SANDBOX/$name")
  seal_vault "$fixture" "$name"
  case "$mutation" in
    missing) rm "$fixture/backup.json" ;;
    symlink)
      rm "$fixture/backup.json"
      ln -s montage.json "$fixture/backup.json"
      ;;
    future)
      jq '.schemaVersion = 99' "$fixture/backup.json" >"$fixture/x"
      mv "$fixture/x" "$fixture/backup.json"
      ;;
    escaping)
      ln -s /etc/passwd "$fixture/home/escape"
      ;;
  esac
  git -C "$fixture" add -A
  git -C "$fixture" commit -q -m "$mutation"
  commit=$(git -C "$fixture" rev-parse HEAD)
  mntg --vault "$fixture" backup show "$commit" --json
  assert_fails "$mutation historical backup is rejected"
  assert_output "not a valid Montage backup"
  assert_equals "$(git -C "$fixture" rev-parse HEAD)" "$commit" \
    "$mutation rejection leaves checkout unchanged"
}

invalid_history_case missing missing
invalid_history_case symlink symlink
invalid_history_case future future
invalid_history_case escaping escaping
