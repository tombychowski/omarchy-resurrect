source "$TESTS_DIR/lib/loadout.sh"

seed_machine
machine_publish repo alpha beta gamma
machine_install native alpha
P1="$SANDBOX/claims-a"; P2="$SANDBOX/claims-b"
write_package_loadout "$P1" First alpha beta
write_package_loadout "$P2" Second alpha beta gamma

apply_yes "$P1"
assert_ok "first loadout is tracked"
apply_yes "$P2"
assert_ok "overlapping second loadout is tracked"
REGISTRY=$(registry_path)
assert_equals "$(jq '[.claims[]|select(.resourceId=="package:alpha")]|length' "$REGISTRY")" "2" "pre-existing package is shared"
assert_equals "$(jq -r '.resources[]|select(.id=="package:alpha")|.cleanupPolicy' "$REGISTRY")" "retain" \
  "first observation protects pre-existing package"
assert_equals "$(jq '[.claims[]|select(.resourceId=="package:beta")]|length' "$REGISTRY")" "2" "mntg-introduced package is shared"
assert_equals "$(jq -r '.resources[]|select(.id=="package:beta")|.cleanupPolicy' "$REGISTRY")" "remove" \
  "later claim does not change original cleanup authority"

ID1=$(jq -r '.loadouts[]|select(.name=="First")|.id' "$REGISTRY")
mntg loadout remove --yes "$ID1"
assert_ok "removing one claimant releases shared claims"
grep -qxF beta "$FAKE_STATE/native.txt" && _pass || _fail "shared mntg package remains installed"
grep -qxF alpha "$FAKE_STATE/native.txt" && _pass || _fail "protected pre-existing package remains installed"

# Equivalent pinned integrations share one canonical resource and do not clone
# again merely to add another claimant.
SHA=$(seed_remote plugin shared-plugin acme.shared)
for spec in "plugin-a:Plugin A" "plugin-b:Plugin B"; do
  dir=${spec%%:*}; title=${spec#*:}; mkdir -p "$SANDBOX/$dir"
  jq -n --arg title "$title" --arg url "$(remote_url shared-plugin)" --arg sha "$SHA" '
    {schemaVersion:1,kind:"omarchy-loadout",name:$title,author:"A",description:"",createdAt:"2026-01-01T00:00:00Z",omarchy:"4",
     packages:{native:[],aur:[]},plugins:[{id:"acme.shared",url:$url,commit:$sha}],webapps:[],theme:{name:"",url:"",commit:""}}' \
    >"$SANDBOX/$dir/profile.json"
done
apply_yes "$SANDBOX/plugin-a"; : >"$CALLS"
apply_yes "$SANDBOX/plugin-b"
assert_ok "equivalent pinned plugin is shared"
assert_equals "$(jq '[.claims[]|select(.resourceId=="plugin:acme.shared")]|length' "$REGISTRY")" "2" \
  "one pinned plugin resource has both claimants"
assert_not_called "git clone" "adding an equivalent pinned claim does not reinstall the plugin"
