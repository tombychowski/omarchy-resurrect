source "$TESTS_DIR/lib/loadout.sh"

seed_machine
machine_publish repo alpha
P="$SANDBOX/registry-profile"
write_package_loadout "$P" Registry alpha

mntg loadout list --json
assert_ok "missing registry is an empty collection"
assert_output '"loadouts": []'

apply_yes "$P"
assert_ok "tracked apply creates the registry"
REGISTRY=$(registry_path)
LOADOUT_ID=$(first_loadout_id)
assert_file "$REGISTRY"
assert_equals "$(stat -c %a "$REGISTRY")" "600" "registry permissions are private"
assert_equals "$(jq -r '.schemaVersion' "$REGISTRY")" "1" "registry schema is versioned"
FIRST_REV=$(jq -r '.revision' "$REGISTRY")
(( FIRST_REV > 0 )) && _pass || _fail "registry revision advances monotonically"
mkdir -p "$XDG_CONFIG_HOME/montage"
printf '.local/state/mntg\n' >"$XDG_CONFIG_HOME/montage/include"
mntg backup --yes --vault "$SANDBOX/registry-vault"
assert_ok "backup succeeds with a broad state include"
assert_no_file "$SANDBOX/registry-vault/home/.local/state/montage/loadouts.json" \
  "machine-local registry is excluded from the vault"

mntg loadout repair --yes "$(first_loadout_id)"
assert_ok "a no-op mutation can read valid state"
assert_equals "$(find "$(dirname "$REGISTRY")" -maxdepth 1 -name '.loadouts.*' | wc -l)" "0" \
  "atomic update leaves no partial temporary file"

cp "$REGISTRY" "$SANDBOX/valid-registry.json"
jq '.schemaVersion=99' "$REGISTRY" >"$SANDBOX/bad.json" && mv "$SANDBOX/bad.json" "$REGISTRY"
mntg loadout remove --yes "$(first_loadout_id 2>/dev/null || echo registry)"
assert_fails "unsupported registry blocks mutation"
assert_output "malformed or unsupported"

cp "$SANDBOX/valid-registry.json" "$REGISTRY"
jq '.claims[0].resourceId="package:missing"' "$REGISTRY" >"$SANDBOX/bad.json" && mv "$SANDBOX/bad.json" "$REGISTRY"
mntg loadout list --json
assert_fails "dangling claim is refused"

cp "$SANDBOX/valid-registry.json" "$REGISTRY"
jq '.claims[0].loadoutId="fabricated-loadout"' "$REGISTRY" >"$SANDBOX/bad.json" && mv "$SANDBOX/bad.json" "$REGISTRY"
mntg loadout list --json
assert_fails "claim for a fabricated loadout is refused"

cp "$SANDBOX/valid-registry.json" "$REGISTRY"
jq '.resources += [.resources[0]]' "$REGISTRY" >"$SANDBOX/bad.json" && mv "$SANDBOX/bad.json" "$REGISTRY"
mntg resource list --json
assert_fails "duplicate resource identity is refused"

cp "$SANDBOX/valid-registry.json" "$REGISTRY"
jq '.resources[0].name="../../etc" | .resources[0].id="package:../../etc" |
  .resources[0].definition.name="../../etc" |
  .claims[0].resourceId="package:../../etc" | .claims[0].requested.name="../../etc"' \
  "$REGISTRY" >"$SANDBOX/bad.json" && mv "$SANDBOX/bad.json" "$REGISTRY"
mntg loadout remove --yes "$LOADOUT_ID"
assert_fails "path-shaped hostile identity cannot authorize deletion"
assert_not_called "pacman -R" "hostile registry invokes no package removal"

cp "$SANDBOX/valid-registry.json" "$REGISTRY"
jq '.resources[0]={id:"plugin:alpha",kind:"plugin",name:"alpha",
      definition:{id:"alpha",url:"file:///tmp/hostile-plugin",commit:""},
      firstObserved:"absent",cleanupPolicy:"remove",state:"missing",evidence:{}} |
    .claims[0].resourceId="plugin:alpha" |
    .claims[0].requested={id:"alpha",url:"file:///tmp/hostile-plugin",commit:""}' \
  "$REGISTRY" >"$SANDBOX/bad.json" && mv "$SANDBOX/bad.json" "$REGISTRY"
mntg loadout repair --yes "$LOADOUT_ID"
assert_fails "unsafe stored resource definitions block mutation"
assert_output "malformed or unsupported"
assert_not_called "hostile-plugin" "unsafe stored remotes never reach git"

cp "$SANDBOX/valid-registry.json" "$REGISTRY"
jq '.claims[0].requested.channels=["native","root"]' "$REGISTRY" >"$SANDBOX/bad.json" && mv "$SANDBOX/bad.json" "$REGISTRY"
mntg loadout repair --yes "$LOADOUT_ID"
assert_fails "invalid stored claim definitions block mutation"

# Historical or imported product ownership is data to port, never Montage
# cleanup authority. Unknown legacy ownership fields fail the exact registry.
cp "$SANDBOX/valid-registry.json" "$REGISTRY"
jq '.resources[0].legacyOwner="ress" | .ressClaims=[{resourceId:"package:alpha",cleanupPolicy:"remove"}]' \
  "$REGISTRY" >"$SANDBOX/bad.json" && mv "$SANDBOX/bad.json" "$REGISTRY"
: >"$CALLS"
mntg loadout remove --yes "$LOADOUT_ID"
assert_fails "imported Ress ownership fields are not adopted"
assert_output "malformed or unsupported" "legacy ownership is refused as non-native state"
assert_not_called "pacman -R" "legacy ownership cannot authorize cleanup"
