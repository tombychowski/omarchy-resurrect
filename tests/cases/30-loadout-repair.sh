source "$TESTS_DIR/lib/loadout.sh"

seed_machine
machine_publish repo alpha
machine_install native alpha
P="$SANDBOX/repair"; write_package_loadout "$P" Repair alpha
apply_yes "$P"
ID=$(first_loadout_id)
assert_equals "$(jq -r '.resources[0].cleanupPolicy' "$(registry_path)")" "retain" "pre-existing package starts protected"
: >"$FAKE_STATE/native.txt"; : >"$CALLS"
BEFORE=$(sha256sum "$(registry_path)" | awk '{print $1}')

mntg loadout repair --dry-run "$ID"
assert_ok "repair dry run previews missing resource"
assert_output "REINSTALL  package:alpha"
assert_not_called "pacman -S" "repair dry run does not install"
assert_equals "$(sha256sum "$(registry_path)" | awk '{print $1}')" "$BEFORE" "repair dry run does not mutate state"

mntg loadout repair --yes "$ID"
assert_ok "confirmed repair reinstalls missing package"
assert_called "pacman -S --needed --noconfirm -- alpha"
mntg loadout check "$ID" --json
assert_ok "repaired loadout is healthy"
assert_output '"healthy": true'
assert_equals "$(jq -r '.resources[0].cleanupPolicy' "$(registry_path)")" "retain" \
  "repair does not adopt a protected resource"
