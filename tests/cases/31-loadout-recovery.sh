source "$TESTS_DIR/lib/loadout.sh"

seed_machine
machine_publish repo alpha
P="$SANDBOX/recovery"; write_package_loadout "$P" Recovery alpha
apply_yes "$P"
ID=$(first_loadout_id); REGISTRY=$(registry_path)

# Seed the window after mutation and before its terminal outcome was recorded.
jq --arg id "$ID" '.operation={kind:"repair",target:$id,phase:"running",actions:[{resourceId:"package:alpha",state:"running"}]} |
  .claims[0].status="pending"' "$REGISTRY" >"$SANDBOX/interrupted.json" && mv "$SANDBOX/interrupted.json" "$REGISTRY"
chmod 600 "$REGISTRY"
ress loadout repair --yes "$ID"
assert_ok "completed interrupted action is reconciled from evidence"
assert_output "reconciled an interrupted repair operation"
assert_equals "$(jq -r '.operation' "$REGISTRY")" "null" "completed recovery clears the journal"
assert_equals "$(jq -r '.claims[0].status' "$REGISTRY")" "healthy" "completed evidence is not treated as pre-existing"

# A cleanup that completed outside the registry write window resumes by
# releasing the now-absent claim, without invoking the remover twice.
: >"$FAKE_STATE/native.txt"
jq --arg id "$ID" '.loadouts[0].state="removal-pending" | .claims[0].status="removal-pending" |
  .operation={kind:"remove",target:$id,phase:"running",actions:[{resourceId:"package:alpha",state:"running"}]}' \
  "$REGISTRY" >"$SANDBOX/interrupted.json" && mv "$SANDBOX/interrupted.json" "$REGISTRY"
chmod 600 "$REGISTRY"; : >"$CALLS"
ress loadout remove --yes "$ID"
assert_ok "interrupted removal resumes to completion"
assert_output "reconciled an interrupted remove operation"
assert_not_called "pacman -R" "completed cleanup is not repeated on resume"
assert_equals "$(jq '.loadouts|length' "$REGISTRY")" "0" "resumed removal clears terminal loadout state"

apply_yes "$P"
ID=$(first_loadout_id); REGISTRY=$(registry_path)

# Ambiguous evidence becomes uncertain rather than silently owned or deleted.
jq --arg id "$ID" '.operation={kind:"remove",target:$id,phase:"running",actions:[{resourceId:"plugin:alpha",state:"running"}]} |
  .resources[0].kind="plugin" | .resources[0].id="plugin:alpha" | .resources[0].name="alpha" |
  .resources[0].definition={id:"alpha",url:"https://example.invalid/a",commit:""} |
  .claims[0].resourceId="plugin:alpha" |
  .claims[0].requested={id:"alpha",url:"https://example.invalid/a",commit:""}' \
  "$REGISTRY" >"$SANDBOX/interrupted.json" && mv "$SANDBOX/interrupted.json" "$REGISTRY"
chmod 600 "$REGISTRY"
mkdir -p "$HOME/.config/omarchy/plugins"
ln -s "$SANDBOX/outside" "$HOME/.config/omarchy/plugins/alpha"
ress loadout repair --yes "$ID"
assert_ok "ambiguous interrupted evidence remains reportable"
assert_equals "$(jq -r '.claims[0].status' "$REGISTRY")" "uncertain" "ambiguous recovery is uncertain"
assert_equals "$(jq -r '.loadouts[0].state' "$REGISTRY")" "pending" "ambiguous recovery needs attention"
