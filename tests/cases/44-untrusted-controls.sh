source "$TESTS_DIR/lib/loadout.sh"

seed_machine
machine_shell_running

# The shared resolver accepts only contained regular files.
PLUGIN_DIR="$REPO_DIR"
source "$REPO_DIR/lib/montage/core.sh"
source "$REPO_DIR/lib/montage/safety.sh"
source "$REPO_DIR/lib/montage/repository/common.sh"
source "$REPO_DIR/lib/montage/repository/transaction.sh"
source "$REPO_DIR/lib/montage/repository/reader.sh"
root="$SANDBOX/control-root"
outside="$SANDBOX/outside"
mkdir -p "$root/nested" "$outside"
printf 'safe\n' >"$root/nested/item"
printf 'outside\n' >"$outside/item"
ln -s "$outside/item" "$root/link"
ln -s nested/item "$root/contained-link"
ln -s "$outside" "$root/parent-link"

resolved=$(safe_control_file "$root" nested/item)
assert_equals "$resolved" "$(realpath "$root/nested/item")" "resolver returns a contained regular file"
safe_control_file "$root" missing >/dev/null; STATUS=$?
assert_fails "resolver refuses a missing file"
safe_control_file "$root" /etc/passwd >/dev/null; STATUS=$?
assert_fails "resolver refuses an absolute path"
safe_control_file "$root" ../outside/item >/dev/null; STATUS=$?
assert_fails "resolver refuses lexical traversal"
safe_control_file "$root" link >/dev/null; STATUS=$?
assert_fails "resolver refuses a final symlink"
safe_control_file "$root" contained-link >/dev/null; STATUS=$?
assert_fails "resolver refuses a contained final symlink"
safe_control_file "$root" parent-link/item >/dev/null; STATUS=$?
assert_fails "resolver refuses a symlinked parent that escapes"

# Stable repository identities are validated before they select a path.
native="$SANDBOX/native-loadouts"
mkdir -p "$native/loadouts/good" "$native/loadouts/final-link" "$native/loadouts"
repository_envelope_json loadouts native-loadouts "2026-10-06T20:00:00Z" >"$native/montage.json"
printf '{}\n' >"$native/loadouts/good/profile.json"
ln -s "$outside/item" "$native/loadouts/final-link/profile.json"
ln -s "$outside" "$native/loadouts/escape"
resolved=$(repository_loadout_profile_path "$native" good)
assert_equals "$resolved" "$(realpath "$native/loadouts/good/profile.json")" \
  "stable loadout id resolves one contained regular profile"
repository_loadout_profile_path "$native" ../outside >/dev/null; STATUS=$?
assert_fails "hostile stable id is refused before path construction"
repository_loadout_profile_path "$native" final-link >/dev/null; STATUS=$?
assert_fails "stable-id reader refuses a final profile symlink"
repository_loadout_profile_path "$native" escape >/dev/null; STATUS=$?
assert_fails "stable-id reader refuses an escaping directory link"

# Historical reads reconstruct exact Git objects in an isolated tree and do
# not move or dirty the configured checkout.
history_repo="$SANDBOX/history-repository"
mkdir -p "$history_repo/payload"
repository_envelope_json loadouts history-repository "2026-10-06T20:00:00Z" >"$history_repo/montage.json"
printf 'old\n' >"$history_repo/payload/value"
git -C "$history_repo" init -q -b main
git -C "$history_repo" add -A
git -C "$history_repo" commit -q -m old
old_commit=$(git -C "$history_repo" rev-parse HEAD)
printf 'new\n' >"$history_repo/payload/value"
git -C "$history_repo" add -A
git -C "$history_repo" commit -q -m new
good_head=$(git -C "$history_repo" rev-parse HEAD)

for hostile_ref in --help 'HEAD^{tree}' '../HEAD' 'refs/heads/main@{1}' $'bad\nref'; do
  repository_ref_valid "$hostile_ref"; STATUS=$?
  assert_fails "hostile repository ref is refused: ${hostile_ref//$'\n'/newline}"
done
assert_equals "$(repository_resolve_commit "$history_repo" HEAD)" "$good_head" \
  "bounded ref resolves to one exact commit"

head_before=$(git -C "$history_repo" rev-parse HEAD)
status_before=$(git -C "$history_repo" status --porcelain=v1 --untracked-files=all)
repository_materialize_history "$history_repo" "$old_commit" loadouts; STATUS=$?
assert_ok "an exact historical tree materializes in isolation"
assert_file_contains "$REPOSITORY_HISTORY_TREE/payload/value" "old" \
  "historical reader returns content from the selected commit"
assert_file_contains "$history_repo/payload/value" "new" \
  "historical reader does not replace the configured checkout"
assert_equals "$(git -C "$history_repo" rev-parse HEAD)" "$head_before" \
  "historical reader does not move HEAD"
assert_equals "$(git -C "$history_repo" status --porcelain=v1 --untracked-files=all)" "$status_before" \
  "historical reader does not dirty the checkout"
history_tree="$REPOSITORY_HISTORY_TREE"
repository_history_release; STATUS=$?
assert_ok "isolated historical tree can be released"
assert_no_file "$history_tree" "released historical tree is removed"

# A historical tree with an escaping link or symlinked envelope is refused.
ln -s "$outside" "$history_repo/payload/escape"
git -C "$history_repo" add -A
git -C "$history_repo" commit -q -m hostile-link
bad_link_commit=$(git -C "$history_repo" rev-parse HEAD)
git -C "$history_repo" checkout -q --detach "$good_head"
repository_materialize_history "$history_repo" "$bad_link_commit" loadouts; STATUS=$?
assert_fails "historical tree with an escaping directory link is refused"

rm "$history_repo/montage.json"
ln -s payload/value "$history_repo/montage.json"
git -C "$history_repo" add -A
git -C "$history_repo" commit -q -m hostile-envelope
bad_envelope_commit=$(git -C "$history_repo" rev-parse HEAD)
git -C "$history_repo" checkout -q --detach "$good_head"
repository_materialize_history "$history_repo" "$bad_envelope_commit" loadouts; STATUS=$?
assert_fails "historical tree with a symlinked repository envelope is refused"
assert_equals "$(git -C "$history_repo" rev-parse HEAD)" "$good_head" \
  "refused historical reads leave the configured checkout selected"

# A fetched vault manifest cannot delegate authority through a symlink.
vault=$(make_vault "$SANDBOX/manifest-vault")
seal_vault "$vault" hostile
mv "$vault/backup.json" "$vault/manifest-target.json"
ln -s manifest-target.json "$vault/backup.json"
git -C "$vault" add -A
git -C "$vault" commit -q -m "symlinked manifest"
: >"$CALLS"
mntg --vault "$vault" restore --dry-run --yes
assert_fails "symlinked vault manifest is refused"
assert_output "selected commit is not a valid Montage backup"
assert_no_output "manifest-target.json" "manifest refusal does not reveal the link target"
assert_no_file "$XDG_STATE_HOME/montage/running" "manifest refusal happens before visible mutation state"
assert_not_called "pacman -S" "manifest refusal performs no package mutation"

# A fetched profile is held to the same rule before apply takes its lock.
profile="$SANDBOX/profile"
mkdir -p "$profile"
write_package_loadout "$outside/profile-source" Outside alpha
ln -s "$outside/profile-source/profile.json" "$profile/profile.json"
: >"$CALLS"
mntg apply --yes "$profile"
assert_fails "symlinked profile is refused"
assert_output "profile.json must be a contained regular file"
assert_no_output "$outside/profile-source" "profile refusal does not reveal the target"
assert_no_file "$XDG_STATE_HOME/montage/running" "profile refusal happens before the operation marker"
assert_no_file "$(registry_path)" "profile refusal creates no registry"
assert_not_called "pacman -S" "profile refusal performs no package mutation"

# Every scalar inventory and encrypted bundle is validated as part of one
# preflight before preview or mutation.
for relative in packages/native.txt plugins/plugins.tsv omarchy/themes.tsv \
  services/user-units.txt secrets/secrets.tar.age; do
  hostile=$(make_vault "$SANDBOX/vault-${relative//\//-}")
  seal_vault "$hostile" hostile
  mkdir -p "$(dirname "$hostile/$relative")"
  target="$hostile/control-target"
  printf 'outside\n' >"$target"
  rm -f "$hostile/$relative"
  ln -s "$(realpath --relative-to="$(dirname "$hostile/$relative")" "$target")" "$hostile/$relative"
  git -C "$hostile" add -A
  git -C "$hostile" commit -q -m "symlinked $relative"
  : >"$CALLS"
  mntg --vault "$hostile" restore --dry-run --yes
  assert_fails "symlinked control file $relative is refused"
  assert_output "selected commit is not a valid Montage backup" "invalid committed controls are refused as one backup"
  assert_no_output "$outside/item" "refusal hides the link target for $relative"
  assert_no_file "$XDG_STATE_HOME/montage/running" "control refusal precedes marker for $relative"
  assert_not_called "pacman -S" "control refusal precedes mutation for $relative"
done

launcher_vault=$(make_vault "$SANDBOX/launcher-vault")
seal_vault "$launcher_vault" hostile
rm -rf "$launcher_vault/webapps/apps"
mkdir -p "$launcher_vault/webapps/apps"
printf 'outside\n' >"$launcher_vault/webapps/launcher-target.desktop"
ln -s ../launcher-target.desktop "$launcher_vault/webapps/apps/Escape.desktop"
git -C "$launcher_vault" add -A
git -C "$launcher_vault" commit -q -m "symlinked launcher"
mntg --vault "$launcher_vault" restore --dry-run --yes
assert_fails "symlinked launcher control file is refused"
assert_output "selected commit is not a valid Montage backup"

# Directory replay keeps contained links but never follows one that escapes the
# fetched subtree.
tree_vault=$(make_vault "$SANDBOX/tree-vault")
mkdir -p "$tree_vault/home/.config/inside"
printf 'kept\n' >"$tree_vault/home/.config/inside/value"
ln -s inside "$tree_vault/home/.config/contained-link"
seal_vault "$tree_vault" tree
mntg --vault "$tree_vault" restore --only config --yes
assert_ok "safe directory replay succeeds"
[[ -L $HOME/.config/contained-link ]] && _pass || _fail "contained symlink is preserved"

escape_tree_vault=$(make_vault "$SANDBOX/escape-tree-vault")
mkdir -p "$escape_tree_vault/home/.config"
ln -s "$outside" "$escape_tree_vault/home/.config/escaping-link"
seal_vault "$escape_tree_vault" tree
mntg --vault "$escape_tree_vault" restore --only config --yes
assert_fails "historical directory replay refuses an escaping symlink"
assert_no_file "$HOME/.config/escaping-link" "escaping symlink is not replayed"
assert_file_contains "$outside/item" "outside" "escaping link does not mutate its target"
