source "$TESTS_DIR/lib/loadout.sh"

seed_machine
machine_publish repo alpha pacman
P="$SANDBOX/package-remove"; write_package_loadout "$P" Packages alpha
apply_yes "$P"
ID=$(first_loadout_id)
printf 'alpha\n' >"$FAKE_STATE/remove-required.txt"
: >"$CALLS"
ress loadout remove --yes "$ID"
assert_fails "dependency refusal leaves removal pending"
assert_output "removal-pending"
assert_called "pacman -R --noconfirm -- alpha"
assert_not_called "--cascade" "package removal never cascades"
assert_not_called "--nodeps" "package removal never ignores dependencies"
assert_equals "$(jq -r '.loadouts[0].state' "$(registry_path)")" "removal-pending" "failed cleanup stays tracked"

: >"$FAKE_STATE/remove-required.txt"
printf 'old-dependency\n' >"$FAKE_STATE/orphaned.txt"
ress loadout remove --yes "$ID"
assert_ok "rerun resumes package cleanup"
assert_output "unneeded dependencies remain (not removed)"
assert_no_output "removed old-dependency" "orphans are report-only"

# Even forged cleanup authority cannot override the critical-package guard.
P2="$SANDBOX/critical"; write_package_loadout "$P2" Critical pacman
machine_install native pacman
apply_yes "$P2"
CID=$(first_loadout_id)
REGISTRY=$(registry_path)
jq '.resources[] |= (if .id=="package:pacman" then .firstObserved="absent" | .cleanupPolicy="remove" else . end)' \
  "$REGISTRY" >"$SANDBOX/forged.json" && mv "$SANDBOX/forged.json" "$REGISTRY"
chmod 600 "$REGISTRY"; : >"$CALLS"
ress loadout remove --yes "$CID"
assert_fails "critical package is protected even from forged ownership"
assert_output "PROTECTED  package:pacman"
assert_not_called "pacman -R --noconfirm -- pacman"

