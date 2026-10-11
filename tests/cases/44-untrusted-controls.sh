source "$TESTS_DIR/lib/loadout.sh"

seed_machine
machine_shell_running

# The shared resolver accepts only contained regular files. Every rejected
# fixture has the same bytes as the accepted file and differs only by its
# unsafe path or symlink topology.
PLUGIN_DIR="$REPO_DIR"
source "$REPO_DIR/lib/montage/core.sh"
source "$REPO_DIR/lib/montage/safety.sh"
source "$REPO_DIR/lib/montage/repository/common.sh"
source "$REPO_DIR/lib/montage/repository/transaction.sh"
source "$REPO_DIR/lib/montage/repository/reader.sh"

assert_equals "$(plain $'visible\033[31m')" "visible[31m" \
  "untrusted terminal text loses control bytes"

quoted_parts=$(webapp_parts 'omarchy-launch-webapp "https://example.invalid/quoted" --profile-directory=Work')
assert_equals "$quoted_parts" $'omarchy-launch-webapp\thttps://example.invalid/quoted\t--profile-directory=Work' \
  "quoted launcher URLs are parsed without retaining quote characters"
long_exec="omarchy-launch-webapp https://example.invalid/"
for i in {1..9}; do long_exec+=" --flag$i=$(printf 'a%.0s' {1..120})"; done
webapp_parts "$long_exec" >/dev/null; STATUS=$?
assert_fails "overlong web app launcher authority is refused before parsing"

root="$SANDBOX/control-root"
outside="$SANDBOX/outside"
mkdir -p "$root/nested" "$outside"
printf 'safe\n' >"$root/nested/item"
printf 'safe\n' >"$outside/item"
ln -s "$outside/item" "$root/link"
ln -s nested/item "$root/contained-link"
ln -s "$outside" "$root/parent-link"

resolved=$(safe_control_file "$root" nested/item)
assert_equals "$resolved" "$(realpath "$root/nested/item")" \
  "resolver returns a contained regular file"
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
mkdir -p "$native/loadouts/good" "$native/loadouts/final-link"
repository_envelope_json native-loadouts "2026-10-06T20:00:00Z" >"$native/montage.json"
write_package_loadout "$native/loadouts/good" Good alpha
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
repository_envelope_json history-repository "2026-10-06T20:00:00Z" >"$history_repo/montage.json"
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
repository_materialize_history "$history_repo" "$old_commit"; STATUS=$?
assert_ok "an exact valid historical tree materializes in isolation"
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

# The hostile counterpart differs only by an escaping link in the selected
# Git tree; validation refuses it while leaving the configured checkout fixed.
ln -s "$outside" "$history_repo/payload/escape"
git -C "$history_repo" add -A
git -C "$history_repo" commit -q -m hostile-link
bad_link_commit=$(git -C "$history_repo" rev-parse HEAD)
git -C "$history_repo" checkout -q --detach "$good_head"
repository_materialize_history "$history_repo" "$bad_link_commit"; STATUS=$?
assert_fails "historical tree with an escaping directory link is refused"
assert_equals "$(git -C "$history_repo" rev-parse HEAD)" "$good_head" \
  "refused historical read leaves the configured checkout selected"

# A standalone profile follows the same contained-regular-file rule before
# apply takes a lock or mutates the machine.
valid_profile="$SANDBOX/valid-profile"
write_package_loadout "$valid_profile" Valid bash
mntg apply --yes "$valid_profile"
assert_ok "contained regular profile counterpart applies"
registry_before=$(sha256sum "$(registry_path)")

profile="$SANDBOX/symlinked-profile"
mkdir -p "$profile"
ln -s "$valid_profile/profile.json" "$profile/profile.json"
: >"$CALLS"
mntg apply --yes "$profile"
assert_fails "symlinked profile is refused"
assert_output "profile.json must be a contained regular file"
assert_no_output "$valid_profile" "profile refusal does not reveal the target"
assert_no_file "$XDG_STATE_HOME/montage/running" \
  "profile refusal happens before the operation marker"
assert_equals "$(sha256sum "$(registry_path)")" "$registry_before" \
  "profile refusal does not change existing applied-loadout state"
assert_not_called "pacman -S" "profile refusal performs no package mutation"
