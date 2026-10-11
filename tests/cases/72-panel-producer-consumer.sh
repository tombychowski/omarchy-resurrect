# Actual CLI payloads exercise the JS adapters and QML process handlers.
source "$TESTS_DIR/lib/loadout.sh"
seed_machine
machine_publish repo alpha
P="$SANDBOX/panel-loadout"
write_package_loadout "$P" Panel alpha
mntg apply --yes "$P"
assert_ok "panel fixture applies"
mntg loadout list --json --contents
printf '%s' "$OUT" >"$SANDBOX/inventory.json"
mntg loadout check --json
printf '%s' "$OUT" >"$SANDBOX/healthy.json"
: >"$FAKE_STATE/native.txt"
mntg loadout check --json
assert_exit 1 "real drift uses the documented health exit"
printf '%s' "$OUT" >"$SANDBOX/unhealthy.json"
mntg port ress inspect "$REPO_DIR/tests/fixtures/ress-v1/loadout" --json
assert_ok "real Ress inspection succeeds"
printf '%s' "$OUT" >"$SANDBOX/ress.json"
NODE=""
while IFS= read -r candidate; do
  if "$candidate" --version >/dev/null 2>&1; then NODE="$candidate"; break; fi
done < <(type -a -p node 2>/dev/null; printf '/usr/bin/node\n/bin/node\n')
"$NODE" "$TESTS_DIR/panel-consumer-test.js" "$REPO_DIR" "$SANDBOX" >"$SANDBOX/consumer.log" 2>&1
STATUS=$?; OUT=$(cat "$SANDBOX/consumer.log")
assert_ok "actual producer output and QML handlers agree"
