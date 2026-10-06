source "$TESTS_DIR/lib/loadout.sh"

seed_machine
machine_shell_running

# The shared resolver accepts only contained regular files.
PLUGIN_DIR="$REPO_DIR"
source "$REPO_DIR/lib/ress/core.sh"
source "$REPO_DIR/lib/ress/safety.sh"
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

# A fetched vault manifest cannot delegate authority through a symlink.
vault=$(make_vault "$SANDBOX/manifest-vault")
seal_vault "$vault" hostile
mv "$vault/ress.json" "$outside/manifest.json"
ln -s "$outside/manifest.json" "$vault/ress.json"
: >"$CALLS"
ress --vault "$vault" restore --dry-run --yes
assert_fails "symlinked vault manifest is refused"
assert_output "vault manifest must be a contained regular file"
assert_no_output "$outside/manifest.json" "manifest refusal does not reveal the link target"
assert_no_file "$XDG_STATE_HOME/ress/running" "manifest refusal happens before visible mutation state"
assert_not_called "pacman -S" "manifest refusal performs no package mutation"

# A fetched profile is held to the same rule before apply takes its lock.
profile="$SANDBOX/profile"
mkdir -p "$profile"
write_package_loadout "$outside/profile-source" Outside alpha
ln -s "$outside/profile-source/profile.json" "$profile/profile.json"
: >"$CALLS"
ress apply --yes "$profile"
assert_fails "symlinked profile is refused"
assert_output "profile.json must be a contained regular file"
assert_no_output "$outside/profile-source" "profile refusal does not reveal the target"
assert_no_file "$XDG_STATE_HOME/ress/running" "profile refusal happens before the operation marker"
assert_no_file "$(registry_path)" "profile refusal creates no registry"
assert_not_called "pacman -S" "profile refusal performs no package mutation"

# Every scalar inventory and encrypted bundle is validated as part of one
# preflight before preview or mutation.
for relative in packages/native.txt plugins/plugins.tsv omarchy/themes.tsv \
  services/user-units.txt secrets/secrets.tar.age; do
  hostile=$(make_vault "$SANDBOX/vault-${relative//\//-}")
  seal_vault "$hostile" hostile
  mkdir -p "$(dirname "$hostile/$relative")"
  rm -f "$hostile/$relative"
  ln -s "$outside/item" "$hostile/$relative"
  : >"$CALLS"
  ress --vault "$hostile" restore --dry-run --yes
  assert_fails "symlinked control file $relative is refused"
  assert_output "$relative must be a contained regular file" "refusal names only the logical control file"
  assert_no_output "$outside/item" "refusal hides the link target for $relative"
  assert_no_file "$XDG_STATE_HOME/ress/running" "control refusal precedes marker for $relative"
  assert_not_called "pacman -S" "control refusal precedes mutation for $relative"
done

launcher_vault=$(make_vault "$SANDBOX/launcher-vault")
seal_vault "$launcher_vault" hostile
rm -rf "$launcher_vault/webapps/apps"
mkdir -p "$launcher_vault/webapps/apps"
ln -s "$outside/item" "$launcher_vault/webapps/apps/Escape.desktop"
ress --vault "$launcher_vault" restore --dry-run --yes
assert_fails "symlinked launcher control file is refused"
assert_output "vault launcher webapps/apps/Escape.desktop must be a contained regular file"

# Directory replay keeps contained links but never follows one that escapes the
# fetched subtree.
tree_vault=$(make_vault "$SANDBOX/tree-vault")
mkdir -p "$tree_vault/home/.config/inside"
printf 'kept\n' >"$tree_vault/home/.config/inside/value"
ln -s inside "$tree_vault/home/.config/contained-link"
ln -s "$outside" "$tree_vault/home/.config/escaping-link"
seal_vault "$tree_vault" tree
ress --vault "$tree_vault" restore --only config --yes
assert_ok "safe directory replay succeeds"
[[ -L $HOME/.config/contained-link ]] && _pass || _fail "contained symlink is preserved"
assert_no_file "$HOME/.config/escaping-link" "escaping symlink is not replayed"
assert_file_contains "$outside/item" "outside" "escaping link does not mutate its target"
