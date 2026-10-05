source "$TESTS_DIR/lib/loadout.sh"

seed_machine
machine_publish repo alpha
P="$SANDBOX/query"; write_package_loadout "$P" Query alpha
apply_yes "$P"
ID=$(first_loadout_id)

ress loadout list --json
assert_ok "loadout list emits JSON"
assert_output '"resourceCount": 1'
assert_no_output '"profile"' "list omits content by default"

ress loadout show "$ID" --json --contents
assert_ok "loadout show can include stored normalized content"
assert_output '"profile"'
assert_output '"claims"'

ress resource show package:alpha --json
assert_ok "resource query emits provenance and relationships"
assert_output '"firstObserved": "absent"'
assert_output "$ID"

ress resource list --json
assert_ok "resource list emits valid JSON"
jq -e '.resources[0].id=="package:alpha"' <<<"$OUT" >/dev/null && _pass || _fail "resource JSON has stable identity" "$OUT"

REGISTRY=$(registry_path)
jq '.resources[0].firstObserved="unknown" | .resources[0].cleanupPolicy="unknown" |
  .resources[0].state="uncertain"' "$REGISTRY" >"$SANDBOX/unknown.json" && mv "$SANDBOX/unknown.json" "$REGISTRY"
ress resource show package:alpha
assert_ok "human resource query reports unknown provenance safely"
assert_output "origin: unknown"
assert_no_output "origin: already present" "unknown provenance is never mislabeled as pre-existing"
