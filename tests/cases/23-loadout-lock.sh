source "$TESTS_DIR/lib/loadout.sh"

seed_machine
machine_publish repo alpha
P="$SANDBOX/lock-profile"
write_package_loadout "$P" Locked alpha
mkdir -p "$XDG_STATE_HOME/montage"

exec 7>"$XDG_STATE_HOME/montage/lock"
flock -n 7
mntg apply --yes "$P"
assert_fails "a concurrent loadout mutation is refused"
assert_output "another mntg operation is already running"
assert_not_called "pacman -S" "blocked operation performs no mutation"
flock -u 7

# Exercise the real core lock and EXIT cleanup in an overlapping process. Every
# mntg invocation installs the cleanup trap, so read-only commands are the
# important adversary: they must not erase another process's marker.
owner_ready="$SANDBOX/owner-ready"
owner_release="$SANDBOX/owner-release"
(
  PLUGIN_DIR="$REPO_DIR"
  source "$REPO_DIR/lib/montage/core.sh"
  trap montage_cleanup EXIT
  take_lock
  : >"$owner_ready"
  while [[ ! -e $owner_release ]]; do sleep 0.02; done
) &
owner_pid=$!
for _ in {1..100}; do [[ -e $owner_ready ]] && break; sleep 0.02; done
assert_file "$owner_ready" "operation-lock owner started in the sandbox"
assert_file "$XDG_STATE_HOME/montage/running" "live owner creates the running marker"
owner_token=$(<"$XDG_STATE_HOME/montage/running")

mntg --version
assert_ok "version can run while another operation owns the lock"
assert_file_contains "$XDG_STATE_HOME/montage/running" "$owner_token" "version does not erase the owner's marker"

mntg --help
assert_ok "help can run while another operation owns the lock"
assert_file_contains "$XDG_STATE_HOME/montage/running" "$owner_token" "help does not erase the owner's marker"

printf 'replacement-owner\n' >"$XDG_STATE_HOME/montage/running"
: >"$owner_release"
wait "$owner_pid"
assert_file_contains "$XDG_STATE_HOME/montage/running" "replacement-owner" "owner cleanup does not erase a replaced marker"
rm -f "$XDG_STATE_HOME/montage/running"

# A dry-run process owns the lock but never owns visible panel state.
dry_ready="$SANDBOX/dry-owner-ready"
dry_release="$SANDBOX/dry-owner-release"
(
  PLUGIN_DIR="$REPO_DIR"
  source "$REPO_DIR/lib/montage/core.sh"
  trap montage_cleanup EXIT
  DRY_RUN=1
  take_lock
  : >"$dry_ready"
  while [[ ! -e $dry_release ]]; do sleep 0.02; done
) &
dry_pid=$!
for _ in {1..100}; do [[ -e $dry_ready ]] && break; sleep 0.02; done
assert_file "$dry_ready" "dry-run lock owner started in the sandbox"
assert_no_file "$XDG_STATE_HOME/montage/running" "overlapping dry run creates no running marker"
mntg --version
assert_ok "read command can overlap a dry-run lock owner"
assert_no_file "$XDG_STATE_HOME/montage/running" "read cleanup creates or removes no dry-run marker"
: >"$dry_release"
wait "$dry_pid"
assert_no_file "$XDG_STATE_HOME/montage/running" "dry-run owner cleanup creates no marker"

mntg apply --dry-run "$P"
assert_ok "dry run can plan after the lock is released"
assert_no_file "$(registry_path)" "dry run creates no registry"
assert_no_file "$XDG_STATE_HOME/montage/running" "dry run creates no running marker"

mntg apply --yes "$P"
assert_ok "confirmed apply succeeds"
assert_no_file "$XDG_STATE_HOME/montage/running" "running marker is cleaned at exit"
