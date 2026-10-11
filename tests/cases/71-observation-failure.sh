source "$TESTS_DIR/lib/loadout.sh"
seed_machine
machine_publish repo alpha beta
machine_install native alpha
P="$SANDBOX/observation"
write_package_loadout "$P" Observation alpha beta

for partial in '' alpha; do
  printf '%s\n' "$partial" >"$FAKE_STATE/inventory-failure.txt"
  : >"$CALLS"
  mntg apply --yes "$P"
  assert_fails "failed inventory is a qualified apply outcome"
  assert_not_called "pacman -S" "failed inventory does not install packages"
  jq -e 'all(.resources[]; .firstObserved=="unknown" and .cleanupPolicy=="unknown")' \
    "$(registry_path)" >/dev/null && _pass || _fail "failed inventory grants no cleanup authority"
  id=$(first_loadout_id)
  mntg loadout check "$id" --json
  assert_fails "failed inventory cannot report healthy"
  assert_output '"currentState": "unverifiable"' "failed inventory is explicit"
  rm "$FAKE_STATE/inventory-failure.txt"
  mntg loadout remove "$id" --yes --keep-modified
  assert_ok "claims with unknown introduction can be released safely"
  pacman -Q alpha >/dev/null; STATUS=$?
  assert_ok "pre-existing package remains after observation failure"
done
