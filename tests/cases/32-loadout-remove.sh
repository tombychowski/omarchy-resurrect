source "$TESTS_DIR/lib/loadout.sh"

seed_machine
machine_publish repo alpha beta gamma
machine_install native alpha
P1="$SANDBOX/remove-a"; P2="$SANDBOX/remove-b"
write_package_loadout "$P1" Remove-A alpha beta
write_package_loadout "$P2" Remove-B beta gamma
apply_yes "$P1"; apply_yes "$P2"
REGISTRY=$(registry_path)
ID1=$(jq -r '.loadouts[]|select(.name=="Remove-A")|.id' "$REGISTRY")
ID2=$(jq -r '.loadouts[]|select(.name=="Remove-B")|.id' "$REGISTRY")

BEFORE=$(sha256sum "$REGISTRY" | awk '{print $1}')
mntg loadout remove --dry-run "$ID1"
assert_ok "removal dry run previews all claims"
assert_output "RETAIN  package:alpha"
assert_output "RELEASE-ONLY  package:beta"
assert_equals "$(sha256sum "$REGISTRY" | awk '{print $1}')" "$BEFORE" "removal dry run changes no state"

montage_answer "n" -- loadout remove "$ID1"
assert_fails "cancelling removal changes nothing"
assert_output "cancelled"
assert_equals "$(sha256sum "$REGISTRY" | awk '{print $1}')" "$BEFORE" "cancelled removal preserves registry state"

: >"$CALLS"
mntg loadout remove --yes "$ID1"
assert_ok "first overlapping loadout is removed"
assert_not_called "pacman -R" "shared and pre-existing resources are retained"

mntg loadout remove --yes "$ID2"
assert_ok "last overlapping loadout is removed"
assert_called "pacman -R --noconfirm -- beta" "last owned shared package is deleted"
assert_called "pacman -R --noconfirm -- gamma" "exclusive owned package is deleted"
grep -qxF alpha "$FAKE_STATE/native.txt" && _pass || _fail "pre-existing package remains"
assert_equals "$(jq '.loadouts|length' "$REGISTRY")" "0" "completed loadouts leave active tracking"

P3="$SANDBOX/already-absent"; write_package_loadout "$P3" Already-Absent delta
machine_publish repo delta
apply_yes "$P3"; ID3=$(first_loadout_id)
grep -vxF delta "$FAKE_STATE/native.txt" >"$FAKE_STATE/native.next" && mv "$FAKE_STATE/native.next" "$FAKE_STATE/native.txt"
: >"$CALLS"
mntg loadout remove --dry-run "$ID3"
assert_ok "already-absent cleanup is previewed"
assert_output "ALREADY-ABSENT  package:delta"
mntg loadout remove --yes "$ID3"
assert_ok "already-absent resource releases its final claim"
assert_not_called "pacman -R --noconfirm -- delta" "already-absent resource is not recreated or removed again"
assert_equals "$(jq '.loadouts|length' "$REGISTRY")" "0" "already-absent cleanup completes tracking removal"
