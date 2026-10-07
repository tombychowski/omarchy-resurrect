# Vault backup builds and validates a complete candidate before publishing it.

seed_machine
mntg init >/dev/null
VAULT="$XDG_DATA_HOME/montage/vault"

mntg backup -m initial >/dev/null
assert_ok "initial backup"
initial_head=$(git -C "$VAULT" rev-parse HEAD)
initial_tree=$(git -C "$VAULT" rev-parse HEAD^{tree})

mntg backup -m duplicate
assert_ok "an unchanged backup succeeds"
assert_output "nothing changed since the last backup"
assert_equals "$(git -C "$VAULT" rev-parse HEAD)" "$initial_head" \
  "an unchanged snapshot creates no commit"

# A candidate that fails whole-snapshot validation never reaches the live tree.
printf 'changed candidate\n' >"$HOME/.bashrc"
MONTAGE_TEST_INVALID_VAULT_STAGE=loadouts mntg backup -m invalid
assert_fails "failed staged validation blocks backup"
assert_output "staged vault snapshot failed validation"
assert_equals "$(git -C "$VAULT" rev-parse HEAD)" "$initial_head" \
  "failed validation creates no commit"
assert_equals "$(git -C "$VAULT" rev-parse HEAD^{tree})" "$initial_tree" \
  "failed validation leaves the published snapshot unchanged"
assert_equals "$(git -C "$VAULT" status --porcelain=v1 --untracked-files=all)" "" \
  "failed validation leaves a clean repository"

# An interruption after moving the prior snapshot leaves a recovery journal.
MONTAGE_TEST_INTERRUPT_AFTER_VAULT_OLD_MOVE=1 mntg backup -m interrupted
assert_fails "interrupted publication is reported"
assert_output "rerun backup to recover"
assert_file "$VAULT/montage.json" "the immutable repository envelope remains present"
assert_no_file "$VAULT/backup.json" "a partial replacement is not exposed as a current backup"
journal=$(find "$XDG_STATE_HOME/montage/vault-publications" -type f -name '*.json' -print -quit)
assert_file "$journal" "interrupted publication leaves a recovery journal"
assert_equals "$(git -C "$VAULT" rev-parse HEAD)" "$initial_head" \
  "interruption creates no commit"

mntg backup -m recovered
assert_ok "the next backup recovers and publishes"
assert_file_contains "$VAULT/home/.bashrc" "changed candidate" \
  "the recovered operation publishes the complete new snapshot"
assert_no_file "$journal" "recovery removes the publication journal"
assert_equals "$(git -C "$VAULT" rev-list --count HEAD)" "2" \
  "recovery creates exactly one new backup commit"
assert_equals "$(git -C "$VAULT" status --porcelain=v1 --untracked-files=all)" "" \
  "the recovered repository is clean"
