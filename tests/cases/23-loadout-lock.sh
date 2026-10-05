source "$TESTS_DIR/lib/loadout.sh"

seed_machine
machine_publish repo alpha
P="$SANDBOX/lock-profile"
write_package_loadout "$P" Locked alpha
mkdir -p "$XDG_STATE_HOME/ress"

exec 7>"$XDG_STATE_HOME/ress/lock"
flock -n 7
ress apply --yes "$P"
assert_fails "a concurrent loadout mutation is refused"
assert_output "another ress operation is already running"
assert_not_called "pacman -S" "blocked operation performs no mutation"
flock -u 7

ress apply --dry-run "$P"
assert_ok "dry run can plan after the lock is released"
assert_no_file "$(registry_path)" "dry run creates no registry"
assert_no_file "$XDG_STATE_HOME/ress/running" "dry run creates no running marker"

ress apply --yes "$P"
assert_ok "confirmed apply succeeds"
assert_no_file "$XDG_STATE_HOME/ress/running" "running marker is cleaned at exit"
