source "$TESTS_DIR/lib/loadout.sh"

seed_machine
machine_publish repo alpha beta gamma delta
P1="$SANDBOX/round-a"; P2="$SANDBOX/round-b"
write_package_loadout "$P1" Round-A alpha beta
write_package_loadout "$P2" Round-B beta gamma
apply_yes "$P1"; apply_yes "$P2"
REGISTRY=$(registry_path)
ID1=$(jq -r '.loadouts[]|select(.name=="Round-A")|.id' "$REGISTRY")
ID2=$(jq -r '.loadouts[]|select(.name=="Round-B")|.id' "$REGISTRY")

grep -vxF beta "$FAKE_STATE/native.txt" >"$FAKE_STATE/native.next" && mv "$FAKE_STATE/native.next" "$FAKE_STATE/native.txt"
mntg loadout check --json
assert_fails "overlapping external removal is visible"
assert_output '"currentState": "missing"'
mntg loadout repair --yes "$ID1"
assert_ok "repairing one claimant restores the shared machine resource"
mntg loadout check --json
assert_ok "all claimants become healthy after shared repair"

write_package_loadout "$P1" Round-A alpha delta
mntg loadout update --yes "$ID1"
assert_ok "one overlapping loadout updates explicitly"
grep -qxF beta "$FAKE_STATE/native.txt" && _pass || _fail "withdrawn shared resource remains for other claimant"
grep -qxF delta "$FAKE_STATE/native.txt" && _pass || _fail "updated resource is installed"

mntg loadout remove --yes "$ID2"
assert_ok "second loadout removes its final claims"
mntg loadout remove --yes "$ID1"
assert_ok "first loadout then removes its final claims"
jq -e '.loadouts==[] and .resources==[] and .claims==[] and .operation==null' "$REGISTRY" >/dev/null && _pass ||
  _fail "round trip ends with valid empty relationship state" "$(jq . "$REGISTRY")"

# Reapply and remove in the opposite order.
apply_yes "$P1"; apply_yes "$P2"
ID1=$(jq -r '.loadouts[]|select(.name=="Round-A")|.id' "$REGISTRY")
ID2=$(jq -r '.loadouts[]|select(.name=="Round-B")|.id' "$REGISTRY")
mntg loadout remove --yes "$ID1"
assert_ok "opposite-order first removal succeeds"
mntg loadout remove --yes "$ID2"
assert_ok "opposite-order final removal succeeds"
jq -e '.loadouts==[] and .resources==[] and .claims==[] and .operation==null' "$REGISTRY" >/dev/null && _pass ||
  _fail "opposite order also preserves registry invariants" "$(jq . "$REGISTRY")"
